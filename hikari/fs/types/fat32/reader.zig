//! Hikari FAT32 Reader

const std = @import("std");

const efi = @import("hikari").efi;
const errors = @import("hikari").fs.errors;
const fat32 = @import("shared").fat32;
const types = @import("hikari").fs.types;
const utils = @import("utils");

const AllocatedBuffer = types.fat32.buffer.AllocatedBuffer;
const BootSector = fat32.types.boot.BootSector;
const ReadError = errors.fat32.ReadError;
const StackEntry = fat32.types.entry.StackEntry;
const cluster = fat32.read.cluster;
const clusters = fat32.constants.clusters;
const stack = fat32.read.stack;
const status = efi.constants.status;

const MediaBinding = struct {
    Source: *const efi.types.block.BlockIoMedia,
    MediaId: u32,
    BlockSize: u32,
    IOAlign: u32,
    LastBlock: u64,

    fn capture(media: *const efi.types.block.BlockIoMedia) MediaBinding {
        return .{
            .Source = media,
            .MediaId = media.MediaId,
            .BlockSize = media.BlockSize,
            .IOAlign = media.IOAlign,
            .LastBlock = media.LastBlock,
        };
    }

    fn matches(self: *const MediaBinding, media: *const efi.types.block.BlockIoMedia) bool {
        return self.Source == media and media.MediaPresent and self.MediaId == media.MediaId and
            self.BlockSize == media.BlockSize and self.IOAlign == media.IOAlign and self.LastBlock == media.LastBlock;
    }
};

const Chain = struct {
    Current: u32,
    Remaining: u32,
    Checkpoint: u32,
    Window: u32 = 1,
    Distance: u32 = 0,

    fn initialize(first_cluster: u32, cluster_count: u32) Chain {
        return .{
            .Current = first_cluster,
            .Remaining = cluster_count,
            .Checkpoint = first_cluster,
        };
    }

    fn advance(self: *Chain, next_cluster: u32) ReadError!void {
        if (self.Remaining <= 1 or next_cluster == self.Checkpoint) return ReadError.InvalidChain;
        self.Remaining -= 1;
        self.Distance += 1;
        if (self.Distance == self.Window) {
            self.Checkpoint = next_cluster;
            self.Window *= 2;
            self.Distance = 0;
        }
        self.Current = next_cluster;
    }
};

pub const Reader = struct {
    BlockIO: *efi.types.protocols.block.BlockIoProtocol,
    BootServices: *efi.types.services.boot.BootServices,
    Media: MediaBinding,
    MediaInvalidated: bool = false,
    PartitionStartLBA: u64,
    PartitionEndLBA: u64,
    VolumeEndLBA: u64,
    FatStartLBA: u64,
    FatEndLBA: u64,
    DataStartLBA: u64,
    SectorsPerCluster: u32,
    BytesPerCluster: u32,
    ClusterCount: u32,
    OriginCluster: u32,
    ClusterAllocation: efi.types.buffer.AlignedBuffer,
    SectorAllocation: efi.types.buffer.AlignedBuffer,

    pub fn initialize(
        block_io: *efi.types.protocols.block.BlockIoProtocol,
        boot_services: *efi.types.services.boot.BootServices,
        partition_start_lba: u64,
        partition_end_lba: u64,
    ) ReadError!Reader {
        const media = MediaBinding.capture(block_io.Media);
        if (!media.Source.MediaPresent) return ReadError.ReadFailed;
        if (partition_start_lba > partition_end_lba or partition_end_lba > media.LastBlock) return ReadError.InvalidPartition;
        const block_size = media.BlockSize;
        if (block_size < @sizeOf(BootSector) or block_size > fat32.constants.sizes.SECTOR_SIZE_MAX or
            (block_size & (block_size - 1)) != 0)
        {
            return ReadError.InvalidBootSector;
        }

        var sector_allocation = efi.buffer.allocate(boot_services, block_size, media.IOAlign) orelse return ReadError.AllocationFailed;
        errdefer efi.buffer.release(boot_services, &sector_allocation);
        if (!media.matches(block_io.Media)) return ReadError.MediaChanged;
        const read_status = block_io.ReadBlocks(block_io, media.MediaId, partition_start_lba, block_size, sector_allocation.Data);
        if (mediaLost(read_status) or !media.matches(block_io.Media)) return ReadError.MediaChanged;
        if (read_status != status.SUCCESS) return ReadError.ReadFailed;

        const boot_sector: *const BootSector = @ptrCast(sector_allocation.Data);
        if (!boot_sector.isValid() or boot_sector.BytesPerSector != block_size or boot_sector.ReservedSectors == 0) {
            return ReadError.InvalidBootSector;
        }

        const sectors_per_cluster: u32 = boot_sector.SectorsPerCluster;
        const total_sectors: u64 = boot_sector.TotalSectors32;
        const fat_sectors: u64 = boot_sector.FatSize32;
        const fat_offset: u64 = boot_sector.ReservedSectors;
        const data_offset = fat_offset + fat_sectors * boot_sector.FatCount;
        const active_fat = boot_sector.activeFatIndex() orelse return ReadError.InvalidBootSector;
        const active_offset = fat_offset + fat_sectors * active_fat;
        if ((sectors_per_cluster & (sectors_per_cluster - 1)) != 0 or total_sectors <= data_offset or
            total_sectors - 1 > partition_end_lba - partition_start_lba)
        {
            return ReadError.InvalidBootSector;
        }

        const cluster_count = (total_sectors - data_offset) / sectors_per_cluster;
        const fat_entries = fat_sectors * (block_size / @sizeOf(u32));
        if (cluster_count + clusters.CLUSTER_DATA_START > @min(fat_entries, clusters.CLUSTER_HIGH_RESERVED_START) or
            !clusterFits(boot_sector.RootCluster, cluster_count))
        {
            return ReadError.InvalidBootSector;
        }

        const bytes_per_cluster = block_size * sectors_per_cluster;
        var cluster_allocation = efi.buffer.allocate(boot_services, bytes_per_cluster, media.IOAlign) orelse return ReadError.AllocationFailed;
        errdefer efi.buffer.release(boot_services, &cluster_allocation);
        if (!media.matches(block_io.Media)) return ReadError.MediaChanged;

        return .{
            .BlockIO = block_io,
            .BootServices = boot_services,
            .Media = media,
            .PartitionStartLBA = partition_start_lba,
            .PartitionEndLBA = partition_end_lba,
            .VolumeEndLBA = partition_start_lba + (total_sectors - 1),
            .FatStartLBA = partition_start_lba + active_offset,
            .FatEndLBA = partition_start_lba + (active_offset + fat_sectors - 1),
            .DataStartLBA = partition_start_lba + data_offset,
            .SectorsPerCluster = sectors_per_cluster,
            .BytesPerCluster = bytes_per_cluster,
            .ClusterCount = @intCast(cluster_count),
            .OriginCluster = boot_sector.RootCluster,
            .ClusterAllocation = cluster_allocation,
            .SectorAllocation = sector_allocation,
        };
    }

    pub fn deinitialize(self: *Reader) void {
        efi.buffer.release(self.BootServices, &self.ClusterAllocation);
        efi.buffer.release(self.BootServices, &self.SectorAllocation);
    }

    pub fn readCluster(self: *Reader, cluster_number: u32) ReadError!void {
        try self.ensureReady();
        if (!clusterFits(cluster_number, self.ClusterCount)) return ReadError.InvalidCluster;
        const cluster_offset = std.math.mul(u64, cluster_number - clusters.CLUSTER_DATA_START, self.SectorsPerCluster) catch
            return ReadError.InvalidCluster;
        const cluster_lba = std.math.add(u64, self.DataStartLBA, cluster_offset) catch return ReadError.InvalidCluster;
        try self.readRange(self.DataStartLBA, self.VolumeEndLBA, cluster_lba, self.SectorsPerCluster, &self.ClusterAllocation);
    }

    pub fn getNextCluster(self: *Reader, cluster_number: u32) ReadError!?u32 {
        try self.ensureReady();
        if (!clusterFits(cluster_number, self.ClusterCount)) return ReadError.InvalidCluster;
        const position = cluster.getFatPosition(cluster_number, self.Media.BlockSize);
        const fat_lba = std.math.add(u64, self.FatStartLBA, position.Sector) catch return ReadError.InvalidCluster;
        if (position.Offset > self.Media.BlockSize - @sizeOf(u32)) return ReadError.InvalidCluster;
        try self.readRange(self.FatStartLBA, self.FatEndLBA, fat_lba, 1, &self.SectorAllocation);
        const fat_entry = std.mem.readInt(u32, self.SectorAllocation.Data[position.Offset..][0..@sizeOf(u32)], .little);
        const next = (cluster.parseFatEntry(fat_entry) catch return ReadError.InvalidCluster) orelse return null;
        if (!clusterFits(next, self.ClusterCount)) return ReadError.InvalidCluster;
        return next;
    }

    pub fn findInStack(self: *Reader, stack_cluster: u32, identity: []const u8) ReadError!?StackEntry {
        var chain = Chain.initialize(stack_cluster, self.ClusterCount);
        while (true) {
            try self.readCluster(chain.Current);
            const entries: [*]const StackEntry = @ptrCast(self.ClusterAllocation.Data);
            for (entries[0 .. self.BytesPerCluster / @sizeOf(StackEntry)]) |*entry| {
                if (entry.isEnd()) return null;
                if (entry.isFree() or entry.isLongIdentity() or entry.isVolumeId()) continue;
                if (stack.entryMatchesIdentity(entry, identity)) return entry.*;
            }
            const next = (try self.getNextCluster(chain.Current)) orelse return null;
            try chain.advance(next);
        }
    }

    pub fn openLocation(self: *Reader, location: []const u8) ReadError!StackEntry {
        try self.ensureReady();
        var current_cluster = self.OriginCluster;
        var is_stack = true;
        var iterator = utils.path.types.iterator.LocationIterator.init(location);
        var last_entry: ?StackEntry = null;
        while (iterator.next()) |component| {
            if (!is_stack) return ReadError.NotAStack;
            const found = (try self.findInStack(current_cluster, component)) orelse return ReadError.NotFound;
            current_cluster = found.getFirstCluster();
            is_stack = found.isStack();
            last_entry = found;
        }
        return last_entry orelse ReadError.NotFound;
    }

    pub fn readUnit(self: *Reader, entry: *const StackEntry, buffer: [*]u8, max_size: u32) ReadError!u32 {
        try self.checkUnit(entry, max_size);
        const unit_size = entry.UnitSize;
        var chain = Chain.initialize(entry.getFirstCluster(), self.ClusterCount);
        var bytes_read: u32 = 0;
        while (bytes_read < unit_size) {
            try self.readCluster(chain.Current);
            const bytes_to_copy = @min(unit_size - bytes_read, self.BytesPerCluster);
            @memcpy(buffer[bytes_read..][0..bytes_to_copy], self.ClusterAllocation.Data[0..bytes_to_copy]);
            bytes_read += bytes_to_copy;
            const next = try self.getNextCluster(chain.Current);
            if (bytes_read == unit_size) {
                if (next != null) return ReadError.InvalidChain;
            } else {
                try chain.advance(next orelse return ReadError.InvalidChain);
            }
        }
        return bytes_read;
    }

    pub fn readUnitToAllocated(self: *Reader, entry: *const StackEntry, max_size: u32) ReadError!AllocatedBuffer {
        const unit = entry.*;
        try self.checkUnit(&unit, max_size);
        var buffer: [*]align(8) u8 = undefined;
        const allocation_status = self.BootServices.AllocatePool(.LoaderData, @max(unit.UnitSize, 1), &buffer);
        if (efi.status.isError(allocation_status)) return ReadError.AllocationFailed;
        errdefer _ = self.BootServices.FreePool(buffer);
        const bytes_read = try self.readUnit(&unit, buffer, unit.UnitSize);
        return .{ .Buffer = buffer, .Size = bytes_read };
    }

    fn ensureReady(self: *Reader) ReadError!void {
        if (self.ClusterAllocation.Size == 0 or self.SectorAllocation.Size == 0) return ReadError.ReaderClosed;
        if (self.MediaInvalidated or !self.Media.matches(self.BlockIO.Media)) {
            self.MediaInvalidated = true;
            return ReadError.MediaChanged;
        }
    }

    fn checkUnit(self: *Reader, entry: *const StackEntry, max_size: u32) ReadError!void {
        try self.ensureReady();
        const volume_bytes = @as(u64, self.ClusterCount) * self.BytesPerCluster;
        if (entry.UnitSize > max_size or entry.UnitSize > volume_bytes) return ReadError.UnitTooLarge;
        if (entry.UnitSize != 0 and !clusterFits(entry.getFirstCluster(), self.ClusterCount)) return ReadError.InvalidCluster;
    }

    fn readRange(self: *Reader, start_lba: u64, end_lba: u64, lba: u64, sector_count: u32, allocation: *const efi.types.buffer.AlignedBuffer) ReadError!void {
        if (start_lba < self.PartitionStartLBA or end_lba > @min(self.PartitionEndLBA, self.VolumeEndLBA, self.Media.LastBlock) or
            lba < start_lba or lba > end_lba or sector_count == 0 or sector_count - 1 > end_lba - lba)
        {
            return ReadError.InvalidCluster;
        }
        const size = std.math.mul(usize, sector_count, self.Media.BlockSize) catch return ReadError.InvalidCluster;
        if (size != allocation.Size) return ReadError.InvalidCluster;
        const read_status = self.BlockIO.ReadBlocks(self.BlockIO, self.Media.MediaId, lba, size, allocation.Data);
        if (mediaLost(read_status) or !self.Media.matches(self.BlockIO.Media)) {
            self.MediaInvalidated = true;
            return ReadError.MediaChanged;
        }
        if (read_status != status.SUCCESS) return ReadError.ReadFailed;
    }
};

fn clusterFits(cluster_number: u32, cluster_count: u64) bool {
    return cluster_number >= clusters.CLUSTER_DATA_START and cluster_number < clusters.CLUSTER_HIGH_RESERVED_START and
        cluster_number - clusters.CLUSTER_DATA_START < cluster_count;
}

fn mediaLost(read_status: efi.types.base.Status) bool {
    return read_status == status.MEDIA_CHANGED or read_status == status.NO_MEDIA;
}
