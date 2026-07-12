//! Hikari FAT32 Reader

const efi = @import("../../efi/efi.zig");
const errors = @import("../errors/errors.zig");
const fat32 = @import("shared").fat32;

const ReadError = errors.fat32.ReadError;
const BootSector = fat32.types.boot.BootSector;
const StackEntry = fat32.types.entry.StackEntry;
const cluster = fat32.read.cluster;
const stack = fat32.read.stack;

pub const Reader = struct {
    BlockIO: *efi.protocols.block.BlockIoProtocol,
    BootServices: *efi.services.boot.BootServices,
    PartitionStartLBA: u64,
    BootSector: BootSector,
    BytesPerSector: u32,
    SectorsPerCluster: u32,
    BytesPerCluster: u32,
    FatStartLBA: u64,
    DataStartLBA: u64,
    OriginCluster: u32,
    ClusterBuffer: [*]u8,
    SectorBuffer: [*]u8,

    pub fn initialize(
        block_io: *efi.protocols.block.BlockIoProtocol,
        boot_services: *efi.services.boot.BootServices,
        partition_start_lba: u64,
    ) ReadError!Reader {
        const block_size = block_io.Media.BlockSize;

        var sector_buffer: [*]align(8) u8 = undefined;
        var allocation_status = boot_services.AllocatePool(
            .LoaderData,
            block_size,
            &sector_buffer,
        );
        if (efi.types.base.isError(allocation_status)) {
            return ReadError.AllocationFailed;
        }

        const read_status = block_io.ReadBlocks(
            block_io,
            block_io.Media.MediaId,
            partition_start_lba,
            block_size,
            sector_buffer,
        );
        if (efi.types.base.isError(read_status)) {
            return ReadError.ReadFailed;
        }

        const boot_sector: *const BootSector = @ptrCast(@alignCast(sector_buffer));
        if (!boot_sector.isValid()) {
            return ReadError.InvalidBootSector;
        }

        const bytes_per_sector: u32 = boot_sector.BytesPerSector;
        const sectors_per_cluster: u32 = boot_sector.SectorsPerCluster;
        const bytes_per_cluster = bytes_per_sector * sectors_per_cluster;

        var cluster_buffer: [*]align(8) u8 = undefined;
        allocation_status = boot_services.AllocatePool(
            .LoaderData,
            bytes_per_cluster,
            &cluster_buffer,
        );
        if (efi.types.base.isError(allocation_status)) {
            return ReadError.AllocationFailed;
        }

        const fat_start_lba = partition_start_lba + boot_sector.getFatStartSector();
        const data_start_lba = partition_start_lba + boot_sector.getDataStartSector();

        return Reader{
            .BlockIO = block_io,
            .BootServices = boot_services,
            .PartitionStartLBA = partition_start_lba,
            .BootSector = boot_sector.*,
            .BytesPerSector = bytes_per_sector,
            .SectorsPerCluster = sectors_per_cluster,
            .BytesPerCluster = bytes_per_cluster,
            .FatStartLBA = fat_start_lba,
            .DataStartLBA = data_start_lba,
            .OriginCluster = boot_sector.RootCluster,
            .ClusterBuffer = cluster_buffer,
            .SectorBuffer = sector_buffer,
        };
    }

    pub fn readCluster(self: *Reader, cluster_number: u32) ReadError!void {
        if (!cluster.isValidCluster(cluster_number)) {
            return ReadError.InvalidCluster;
        }

        const cluster_lba = cluster.clusterToLba(
            cluster_number,
            self.DataStartLBA,
            self.SectorsPerCluster,
        );

        const read_status = self.BlockIO.ReadBlocks(
            self.BlockIO,
            self.BlockIO.Media.MediaId,
            cluster_lba,
            self.BytesPerCluster,
            self.ClusterBuffer,
        );
        if (efi.types.base.isError(read_status)) {
            return ReadError.ReadFailed;
        }
    }

    pub fn getNextCluster(self: *Reader, cluster_number: u32) ReadError!?u32 {
        const position = cluster.getFatPosition(cluster_number, self.BytesPerSector);
        const fat_sector_lba = self.FatStartLBA + position.Sector;

        const read_status = self.BlockIO.ReadBlocks(
            self.BlockIO,
            self.BlockIO.Media.MediaId,
            fat_sector_lba,
            self.BytesPerSector,
            self.SectorBuffer,
        );
        if (efi.types.base.isError(read_status)) {
            return ReadError.ReadFailed;
        }

        const fat_entry_pointer: *align(1) const u32 = @ptrCast(self.SectorBuffer + position.Offset);
        const fat_entry = fat_entry_pointer.*;

        return cluster.parseFatEntry(fat_entry) catch {
            return ReadError.InvalidCluster;
        };
    }

    pub fn findInStack(self: *Reader, stack_cluster: u32, identity: []const u8) ReadError!?StackEntry {
        var current_cluster = stack_cluster;

        while (true) {
            try self.readCluster(current_cluster);

            const entries_per_cluster = self.BytesPerCluster / @sizeOf(StackEntry);
            const entries: [*]const StackEntry = @ptrCast(@alignCast(self.ClusterBuffer));

            var index: usize = 0;
            while (index < entries_per_cluster) : (index += 1) {
                const entry = &entries[index];

                if (entry.isEnd()) {
                    return null;
                }
                if (entry.isFree()) {
                    continue;
                }
                if (entry.isLongIdentity()) {
                    continue;
                }
                if (entry.isVolumeId()) {
                    continue;
                }

                if (stack.entryMatchesIdentity(entry, identity)) {
                    return entry.*;
                }
            }

            const next_cluster = try self.getNextCluster(current_cluster);
            if (next_cluster) |next| {
                current_cluster = next;
            } else {
                return null;
            }
        }
    }

    pub fn openLocation(self: *Reader, location: []const u8) ReadError!StackEntry {
        var current_cluster = self.OriginCluster;
        var is_stack = true;

        var iterator = stack.LocationIterator.init(location);
        var last_entry: ?StackEntry = null;

        while (iterator.next()) |component| {
            if (!is_stack) {
                return ReadError.NotAStack;
            }

            const entry = try self.findInStack(current_cluster, component);

            if (entry) |found| {
                current_cluster = found.getFirstCluster();
                is_stack = found.isStack();
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

    pub fn readUnit(self: *Reader, entry: *const StackEntry, buffer: [*]u8, max_size: u32) ReadError!u32 {
        const unit_size = entry.UnitSize;
        if (unit_size > max_size) {
            return ReadError.UnitTooLarge;
        }

        var current_cluster = entry.getFirstCluster();
        var bytes_read: u32 = 0;

        while (bytes_read < unit_size) {
            try self.readCluster(current_cluster);

            const bytes_remaining = unit_size - bytes_read;
            const bytes_to_copy = if (bytes_remaining < self.BytesPerCluster) bytes_remaining else self.BytesPerCluster;

            var index: u32 = 0;
            while (index < bytes_to_copy) : (index += 1) {
                buffer[bytes_read + index] = self.ClusterBuffer[index];
            }

            bytes_read += bytes_to_copy;

            if (bytes_read < unit_size) {
                const next_cluster = try self.getNextCluster(current_cluster);
                if (next_cluster) |next| {
                    current_cluster = next;
                } else {
                    break;
                }
            }
        }

        return bytes_read;
    }

    pub fn readUnitToAllocated(self: *Reader, entry: *const StackEntry) ReadError!struct { Buffer: [*]u8, Size: u32 } {
        const unit_size = entry.UnitSize;

        var buffer: [*]align(8) u8 = undefined;
        const allocation_status = self.BootServices.AllocatePool(
            .LoaderData,
            unit_size,
            &buffer,
        );
        if (efi.types.base.isError(allocation_status)) {
            return ReadError.AllocationFailed;
        }

        const bytes_read = try self.readUnit(entry, buffer, unit_size);
        return .{ .Buffer = buffer, .Size = bytes_read };
    }
};
