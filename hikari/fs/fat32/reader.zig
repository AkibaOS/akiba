//! Hikari FAT32 Reader

const efi = @import("../../efi/efi.zig");
const constants = @import("constants.zig");
const types = @import("types.zig");

pub const ReadError = error{
    invalid_boot_sector,
    invalid_fs_info,
    read_failed,
    allocation_failed,
    not_found,
    not_a_stack,
    invalid_cluster,
    unit_too_large,
};

pub const Reader = struct {
    block_io: *efi.protocols.BlockIoProtocol,
    boot_services: *efi.services.BootServices,
    partition_start_lba: u64,
    boot_sector: types.BootSector,
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
            return ReadError.allocation_failed;
        }

        const read_status = block_io.read_blocks(
            block_io,
            block_io.media.media_id,
            partition_start_lba,
            block_size,
            sector_buffer,
        );
        if (efi.types.is_error(read_status)) {
            return ReadError.read_failed;
        }

        const boot_sector: *const types.BootSector = @ptrCast(@alignCast(sector_buffer));
        if (!boot_sector.is_valid()) {
            return ReadError.invalid_boot_sector;
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
            return ReadError.allocation_failed;
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
            .origin_cluster = boot_sector.origin_cluster,
            .cluster_buffer = cluster_buffer,
            .sector_buffer = sector_buffer,
        };
    }

    pub fn read_cluster(self: *Reader, cluster: u32) ReadError!void {
        if (cluster < 2) {
            return ReadError.invalid_cluster;
        }

        const cluster_lba = self.data_start_lba + (@as(u64, cluster - 2) * self.sectors_per_cluster);
        const read_status = self.block_io.read_blocks(
            self.block_io,
            self.block_io.media.media_id,
            cluster_lba,
            self.bytes_per_cluster,
            self.cluster_buffer,
        );
        if (efi.types.is_error(read_status)) {
            return ReadError.read_failed;
        }
    }

    pub fn get_next_cluster(self: *Reader, cluster: u32) ReadError!?u32 {
        const fat_offset = cluster * 4;
        const fat_sector = fat_offset / self.bytes_per_sector;
        const fat_offset_in_sector = fat_offset % self.bytes_per_sector;

        const fat_sector_lba = self.fat_start_lba + fat_sector;
        const read_status = self.block_io.read_blocks(
            self.block_io,
            self.block_io.media.media_id,
            fat_sector_lba,
            self.bytes_per_sector,
            self.sector_buffer,
        );
        if (efi.types.is_error(read_status)) {
            return ReadError.read_failed;
        }

        const fat_entry_ptr: *align(1) const u32 = @ptrCast(self.sector_buffer + fat_offset_in_sector);
        const next_cluster = fat_entry_ptr.* & constants.cluster_mask;

        if (next_cluster >= constants.cluster_end_of_chain_start) {
            return null;
        }
        if (next_cluster == constants.cluster_bad) {
            return ReadError.invalid_cluster;
        }
        if (next_cluster < 2) {
            return ReadError.invalid_cluster;
        }

        return next_cluster;
    }

    pub fn find_in_stack(self: *Reader, stack_cluster: u32, identity: []const u8) ReadError!?types.StackEntry {
        var current_cluster = stack_cluster;

        while (true) {
            try self.read_cluster(current_cluster);

            const entries_per_cluster = self.bytes_per_cluster / @sizeOf(types.StackEntry);
            const entries: [*]const types.StackEntry = @ptrCast(@alignCast(self.cluster_buffer));

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

                var short_identity_buffer: [12]u8 = undefined;
                const short_identity_len = entry.get_short_identity(&short_identity_buffer);
                const short_identity = short_identity_buffer[0..short_identity_len];

                if (case_insensitive_equal(short_identity, identity)) {
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

    pub fn open_location(self: *Reader, location: []const u8) ReadError!types.StackEntry {
        var current_cluster = self.origin_cluster;
        var is_stack = true;

        var start: usize = 0;
        if (location.len > 0 and (location[0] == '/' or location[0] == '\\')) {
            start = 1;
        }

        var iter_start = start;
        while (iter_start < location.len) {
            if (!is_stack) {
                return ReadError.not_a_stack;
            }

            var iter_end = iter_start;
            while (iter_end < location.len and location[iter_end] != '/' and location[iter_end] != '\\') {
                iter_end += 1;
            }

            if (iter_end == iter_start) {
                iter_start = iter_end + 1;
                continue;
            }

            const component = location[iter_start..iter_end];
            const entry = try self.find_in_stack(current_cluster, component);

            if (entry) |found| {
                current_cluster = found.get_first_cluster();
                is_stack = found.is_stack();

                if (iter_end >= location.len) {
                    return found;
                }
            } else {
                return ReadError.not_found;
            }

            iter_start = iter_end + 1;
        }

        return ReadError.not_found;
    }

    pub fn read_unit(self: *Reader, entry: *const types.StackEntry, buffer: [*]u8, max_size: u32) ReadError!u32 {
        const unit_size = entry.unit_size;
        if (unit_size > max_size) {
            return ReadError.unit_too_large;
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

    pub fn read_unit_to_allocated(self: *Reader, entry: *const types.StackEntry) ReadError!struct { buffer: [*]u8, size: u32 } {
        const unit_size = entry.unit_size;

        var buffer: [*]align(8) u8 = undefined;
        const alloc_status = self.boot_services.allocate_pool(
            .loader_data,
            unit_size,
            &buffer,
        );
        if (efi.types.is_error(alloc_status)) {
            return ReadError.allocation_failed;
        }

        const bytes_read = try self.read_unit(entry, buffer, unit_size);
        return .{ .buffer = buffer, .size = bytes_read };
    }
};

fn case_insensitive_equal(a: []const u8, b: []const u8) bool {
    if (a.len != b.len) {
        return false;
    }
    for (a, b) |char_a, char_b| {
        const upper_a = if (char_a >= 'a' and char_a <= 'z') char_a - 32 else char_a;
        const upper_b = if (char_b >= 'a' and char_b <= 'z') char_b - 32 else char_b;
        if (upper_a != upper_b) {
            return false;
        }
    }
    return true;
}
