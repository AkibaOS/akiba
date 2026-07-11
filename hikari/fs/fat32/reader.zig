//! Hikari FAT32 Reader

const efi = @import("../../efi/efi.zig");
const shared_fat32 = @import("shared").fat32;

// Import shared types
const BootSector = shared_fat32.BootSector;
const FsInfo = shared_fat32.FsInfo;
const StackEntry = shared_fat32.StackEntry;

const constants = shared_fat32.constants;
const read_ops = shared_fat32.read;

pub const ReadError = error{
    InvalidBootSector,
    InvalidFsInfo,
    ReadFailed,
    AllocationFailed,
    NotFound,
    NotAStack,
    InvalidCluster,
    UnitTooLarge,
};

pub const Reader = struct {
    block_io: *efi.protocols.BlockIoProtocol,
    boot_services: *efi.services.BootServices,
    partition_start_lba: u64,
    boot_sector: BootSector,
    bytes_per_sector: u32,
    sectors_per_cluster: u32,
    bytes_per_cluster: u32,
    fat_start_lba: u64,
    data_start_lba: u64,
    origin_cluster: u32,
    cluster_buffer: [*]u8,
    sector_buffer: [*]u8,

    pub fn initialize(
        block_io: *efi.protocols.BlockIoProtocol,
        boot_services: *efi.services.BootServices,
        partition_start_lba: u64,
    ) ReadError!Reader {
        const block_size = block_io.media.block_size;

        var sector_buffer: [*]align(8) u8 = undefined;
        var alloc_status = boot_services.allocate_pool(
            .loader_data,
            block_size,
            &sector_buffer,
        );
        if (efi.types.is_error(alloc_status)) {
            return ReadError.AllocationFailed;
        }

        const read_status = block_io.read_blocks(
            block_io,
            block_io.media.media_id,
            partition_start_lba,
            block_size,
            sector_buffer,
        );
        if (efi.types.is_error(read_status)) {
            return ReadError.ReadFailed;
        }

        const boot_sector: *const BootSector = @ptrCast(@alignCast(sector_buffer));
        if (!boot_sector.is_valid()) {
            return ReadError.InvalidBootSector;
        }

        const bytes_per_sector: u32 = boot_sector.bytes_per_sector;
        const sectors_per_cluster: u32 = boot_sector.sectors_per_cluster;
        const bytes_per_cluster = bytes_per_sector * sectors_per_cluster;

        var cluster_buffer: [*]align(8) u8 = undefined;
        alloc_status = boot_services.allocate_pool(
            .loader_data,
            bytes_per_cluster,
            &cluster_buffer,
        );
        if (efi.types.is_error(alloc_status)) {
            return ReadError.AllocationFailed;
        }

        const fat_start_lba = partition_start_lba + boot_sector.get_fat_start_sector();
        const data_start_lba = partition_start_lba + boot_sector.get_data_start_sector();

        return Reader{
            .block_io = block_io,
            .boot_services = boot_services,
            .partition_start_lba = partition_start_lba,
            .boot_sector = boot_sector.*,
            .bytes_per_sector = bytes_per_sector,
            .sectors_per_cluster = sectors_per_cluster,
            .bytes_per_cluster = bytes_per_cluster,
            .fat_start_lba = fat_start_lba,
            .data_start_lba = data_start_lba,
            .origin_cluster = boot_sector.root_cluster,
            .cluster_buffer = cluster_buffer,
            .sector_buffer = sector_buffer,
        };
    }

    pub fn read_cluster(self: *Reader, cluster: u32) ReadError!void {
        if (!read_ops.is_valid_cluster(cluster)) {
            return ReadError.InvalidCluster;
        }

        const cluster_lba = read_ops.cluster_to_lba(
            cluster,
            self.data_start_lba,
            self.sectors_per_cluster,
        );

        const read_status = self.block_io.read_blocks(
            self.block_io,
            self.block_io.media.media_id,
            cluster_lba,
            self.bytes_per_cluster,
            self.cluster_buffer,
        );
        if (efi.types.is_error(read_status)) {
            return ReadError.ReadFailed;
        }
    }

    pub fn get_next_cluster(self: *Reader, cluster: u32) ReadError!?u32 {
        const pos = read_ops.get_fat_position(cluster, self.bytes_per_sector);
        const fat_sector_lba = self.fat_start_lba + pos.sector;

        const read_status = self.block_io.read_blocks(
            self.block_io,
            self.block_io.media.media_id,
            fat_sector_lba,
            self.bytes_per_sector,
            self.sector_buffer,
        );
        if (efi.types.is_error(read_status)) {
            return ReadError.ReadFailed;
        }

        const fat_entry_ptr: *align(1) const u32 = @ptrCast(self.sector_buffer + pos.offset);
        const fat_entry = fat_entry_ptr.*;

        return read_ops.parse_fat_entry(fat_entry) catch |err| switch (err) {
            read_ops.ClusterError.BadCluster, read_ops.ClusterError.InvalidCluster => return ReadError.InvalidCluster,
            else => return ReadError.InvalidCluster,
        };
    }

    pub fn find_in_stack(self: *Reader, stack_cluster: u32, identity: []const u8) ReadError!?StackEntry {
        var current_cluster = stack_cluster;

        while (true) {
            try self.read_cluster(current_cluster);

            const entries_per_cluster = self.bytes_per_cluster / @sizeOf(StackEntry);
            const entries: [*]const StackEntry = @ptrCast(@alignCast(self.cluster_buffer));

            var i: usize = 0;
            while (i < entries_per_cluster) : (i += 1) {
                const entry = &entries[i];

                if (entry.is_end()) {
                    return null;
                }
                if (entry.is_free()) {
                    continue;
                }
                if (entry.is_long_identity()) {
                    continue;
                }
                if (entry.is_volume_id()) {
                    continue;
                }

                if (read_ops.entry_matches_identity(entry, identity)) {
                    return entry.*;
                }
            }

            const next_cluster = try self.get_next_cluster(current_cluster);
            if (next_cluster) |next| {
                current_cluster = next;
            } else {
                return null;
            }
        }
    }

    pub fn open_location(self: *Reader, location: []const u8) ReadError!StackEntry {
        var current_cluster = self.origin_cluster;
        var is_stack = true;

        var iter = read_ops.LocationIterator.init(location);
        var last_entry: ?StackEntry = null;

        while (iter.next()) |component| {
            if (!is_stack) {
                return ReadError.NotAStack;
            }

            const entry = try self.find_in_stack(current_cluster, component);

            if (entry) |found| {
                current_cluster = found.get_first_cluster();
                is_stack = found.is_stack();
                last_entry = found;
            } else {
                return ReadError.NotFound;
            }
        }

        if (last_entry) |entry| {
            return entry;
        }

        return ReadError.NotFound;
    }

    pub fn read_unit(self: *Reader, entry: *const StackEntry, buffer: [*]u8, max_size: u32) ReadError!u32 {
        const unit_size = entry.unit_size;
        if (unit_size > max_size) {
            return ReadError.UnitTooLarge;
        }

        var current_cluster = entry.get_first_cluster();
        var bytes_read: u32 = 0;

        while (bytes_read < unit_size) {
            try self.read_cluster(current_cluster);

            const bytes_remaining = unit_size - bytes_read;
            const bytes_to_copy = if (bytes_remaining < self.bytes_per_cluster) bytes_remaining else self.bytes_per_cluster;

            var i: u32 = 0;
            while (i < bytes_to_copy) : (i += 1) {
                buffer[bytes_read + i] = self.cluster_buffer[i];
            }

            bytes_read += bytes_to_copy;

            if (bytes_read < unit_size) {
                const next_cluster = try self.get_next_cluster(current_cluster);
                if (next_cluster) |next| {
                    current_cluster = next;
                } else {
                    break;
                }
            }
        }

        return bytes_read;
    }

    pub fn read_unit_to_allocated(self: *Reader, entry: *const StackEntry) ReadError!struct { buffer: [*]u8, size: u32 } {
        const unit_size = entry.unit_size;

        var buffer: [*]align(8) u8 = undefined;
        const alloc_status = self.boot_services.allocate_pool(
            .loader_data,
            unit_size,
            &buffer,
        );
        if (efi.types.is_error(alloc_status)) {
            return ReadError.AllocationFailed;
        }

        const bytes_read = try self.read_unit(entry, buffer, unit_size);
        return .{ .buffer = buffer, .size = bytes_read };
    }
};
