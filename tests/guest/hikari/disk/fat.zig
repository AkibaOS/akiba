//! Dormant FAT Reader Boundary Regressions

const std = @import("std");

const constants = @import("tests").guest.constants.acquisition;
const efi = @import("hikari").efi;
const fat = @import("hikari").fs.types.fat32.reader;
const fixture = @import("tests").guest.hikari.disk.fixture;
const format = @import("shared").fat32;
const labels = @import("tests").guest.strings.acquisition;
const verify = @import("tests").guest.support.verify;

const BootSector = format.types.boot.BootSector;
const StackEntry = format.types.entry.StackEntry;
const clusters = format.constants.clusters;

pub fn run() !void {
    mismatch();
    try lifecycle();
    try mediaChanges();
    try unitFailure();
    try exactUnit();
    failures();
    geometry();
    try extents();
    try activeFatCopy();
    try directoryChains();
}

fn activeFatCopy() !void {
    fixture.reset();
    const boot = encode(0, constants.BLOCK_BYTES);
    boot.FatCount = 2;
    boot.ExtFlags = format.constants.flags.MIRRORING_DISABLED | 1;
    const root_cluster = clusters.CLUSTER_DATA_START;
    fixture.writeU32(sector(2), root_cluster * @sizeOf(u32), clusters.CLUSTER_EOC);
    var reader = try mount(0, fixture.media.LastBlock);
    defer if (!reader.deinitialize()) verify.failure(error.ReleaseFailed);
    verify.require((try reader.getNextCluster(root_cluster)) == null and reader.FatStartLBA == 2 and reader.DataStartLBA == 3, labels.FAT_ACTIVE_COPY);
    if (!reader.deinitialize()) verify.failure(error.ReleaseFailed);
    boot.ExtFlags = format.constants.flags.MIRRORING_DISABLED | 2;
    verify.require(rejects(0, fixture.media.LastBlock, error.InvalidBootSector), labels.FAT_ACTIVE_COPY);
}

fn mismatch() void {
    fixture.reset();
    fixture.media.IOAlign = 1;
    _ = encode(0, constants.FAT_MISMATCH_BYTES);
    verify.require(rejects(0, fixture.media.LastBlock, error.InvalidBootSector), labels.FAT_SECTOR_MISMATCH);
    verify.require(fixture.clean(), labels.FAT_INITIALIZATION_RELEASE);
}

fn lifecycle() !void {
    fixture.reset();
    _ = encode(0, constants.BLOCK_BYTES);
    link(0, clusters.CLUSTER_DATA_START, clusters.CLUSTER_EOC);
    var reader = try mount(0, fixture.media.LastBlock);
    defer if (!reader.deinitialize()) verify.failure(error.ReleaseFailed);
    const aligned = @intFromPtr(reader.ClusterAllocation.Data) % constants.IO_ALIGNMENT == 0 and
        @intFromPtr(reader.SectorAllocation.Data) % constants.IO_ALIGNMENT == 0 and fixture.live() == 2;
    const terminal = try reader.getNextCluster(clusters.CLUSTER_DATA_START);
    try reader.readCluster(clusters.CLUSTER_DATA_START);
    if (!reader.deinitialize()) verify.failure(error.ReleaseFailed);
    if (!reader.deinitialize()) verify.failure(error.ReleaseFailed);
    verify.require(aligned and terminal == null and fixture.device.FreeCalls == 2 and fixture.clean(), labels.FAT_LIFECYCLE);

    const entry: StackEntry = std.mem.zeroes(StackEntry);
    var unused: [constants.UNIT_PAYLOAD.len]u8 = undefined;
    const read_calls = fixture.device.ReadCalls;
    const allocate_calls = fixture.device.AllocateCalls;
    const cluster_closed = failedWith(reader.readCluster(clusters.CLUSTER_DATA_START), error.ReaderClosed);
    const link_closed = failedWith(reader.getNextCluster(clusters.CLUSTER_DATA_START), error.ReaderClosed);
    const directory_closed = failedWith(reader.findInStack(clusters.CLUSTER_DATA_START, labels.FAT_MISSING_IDENTITY), error.ReaderClosed);
    const location_closed = failedWith(reader.openLocation(labels.FAT_MISSING_IDENTITY), error.ReaderClosed);
    const unit_closed = failedWith(reader.readUnit(&entry, &unused, unused.len), error.ReaderClosed);
    const allocated_closed = rejectsAllocated(&reader, &entry, constants.UNIT_PAYLOAD.len, error.ReaderClosed);
    verify.require(cluster_closed and link_closed and directory_closed and location_closed and unit_closed and allocated_closed and
        fixture.device.ReadCalls == read_calls and fixture.device.AllocateCalls == allocate_calls and fixture.clean(), labels.FAT_MEDIA);
}

fn mediaChanges() !void {
    for (0..5) |change| {
        fixture.reset();
        _ = encode(0, constants.BLOCK_BYTES);
        var reader = try mount(0, fixture.media.LastBlock);
        defer if (!reader.deinitialize()) verify.failure(error.ReleaseFailed);
        const original_media = fixture.media;
        switch (change) {
            0 => fixture.media.MediaId += 1,
            1 => fixture.media.MediaPresent = false,
            2 => fixture.media.BlockSize *= 2,
            3 => fixture.media.LastBlock += 1,
            else => fixture.media.IOAlign = 1,
        }
        const entry: StackEntry = std.mem.zeroes(StackEntry);
        const rejected = rejectsAllocated(&reader, &entry, constants.UNIT_PAYLOAD.len, error.MediaChanged);
        fixture.media = original_media;
        const stale = failedWith(reader.readCluster(clusters.CLUSTER_DATA_START), error.MediaChanged);
        if (!reader.deinitialize()) verify.failure(error.ReleaseFailed);
        verify.require(rejected and stale and fixture.device.ReadCalls == 1 and fixture.device.AllocateCalls == 2 and fixture.clean(), labels.FAT_MEDIA);
    }
}

fn unitFailure() !void {
    fixture.reset();
    _ = encode(0, constants.BLOCK_BYTES);
    var reader = try mount(0, fixture.media.LastBlock);
    defer if (!reader.deinitialize()) verify.failure(error.ReleaseFailed);
    var entry: StackEntry = std.mem.zeroes(StackEntry);
    entry.setFirstCluster(clusters.CLUSTER_DATA_START);
    entry.UnitSize = constants.UNIT_PAYLOAD.len;
    fixture.device.FailLBA = reader.DataStartLBA;
    var backing: efi.types.buffer.PoolClaim = .{};
    const failed = failedWith(reader.readUnitToAllocated(&entry, constants.UNIT_PAYLOAD.len, &backing), error.ReadFailed);
    fixture.device.FailFree = fixture.device.FreeCalls + 1;
    const refused = !efi.buffer.releasePool(&fixture.services, &backing);
    const retained = backing.Allocation != null and fixture.live() == 3;
    const released = efi.buffer.releasePool(&fixture.services, &backing);
    verify.require(failed and refused and retained and released and backing.isEmpty() and fixture.live() == 2, labels.FAT_UNIT_RELEASE);
    if (!reader.deinitialize()) verify.failure(error.ReleaseFailed);
    verify.require(fixture.clean(), labels.FAT_INITIALIZATION_RELEASE);
}

fn exactUnit() !void {
    fixture.reset();
    _ = encode(0, constants.BLOCK_BYTES);
    const first_cluster = clusters.CLUSTER_DATA_START;
    link(0, first_cluster, clusters.CLUSTER_EOC);
    @memcpy(sector(2)[0..constants.UNIT_PAYLOAD.len], &constants.UNIT_PAYLOAD);

    var reader = try mount(0, fixture.media.LastBlock);
    defer if (!reader.deinitialize()) verify.failure(error.ReleaseFailed);
    var entry: StackEntry = std.mem.zeroes(StackEntry);
    entry.setFirstCluster(first_cluster);
    entry.UnitSize = constants.UNIT_PAYLOAD.len;
    const size_rejected = rejectsAllocated(&reader, &entry, entry.UnitSize - 1, error.UnitTooLarge);
    const caller_bound = fixture.device.AllocateCalls == 2 and fixture.device.ReadCalls == 1;
    entry.UnitSize = constants.DISK_BYTES;
    const volume_rejected = rejectsAllocated(&reader, &entry, entry.UnitSize, error.UnitTooLarge);
    const volume_bound = fixture.device.AllocateCalls == 2 and fixture.device.ReadCalls == 1;

    entry.UnitSize = constants.UNIT_PAYLOAD.len;
    var backing: efi.types.buffer.PoolClaim = .{};
    defer if (!efi.buffer.releasePool(&fixture.services, &backing)) verify.failure(error.ReleaseFailed);
    const result = try reader.readUnitToAllocated(&entry, entry.UnitSize, &backing);
    const exact = result.Size == constants.UNIT_PAYLOAD.len and std.mem.eql(u8, result.Buffer[0..result.Size], &constants.UNIT_PAYLOAD);
    if (!efi.buffer.releasePool(&fixture.services, &backing)) verify.failure(error.ReleaseFailed);

    entry.UnitSize = constants.BLOCK_BYTES + 1;
    const truncated = rejectsAllocated(&reader, &entry, entry.UnitSize, error.InvalidChain) and fixture.live() == 2;
    entry.UnitSize = constants.UNIT_PAYLOAD.len;
    link(0, first_cluster, first_cluster + 1);
    const overlong = rejectsAllocated(&reader, &entry, entry.UnitSize, error.InvalidChain) and fixture.live() == 2;
    const read_calls = fixture.device.ReadCalls;
    entry = std.mem.zeroes(StackEntry);
    const empty = try reader.readUnitToAllocated(&entry, 0, &backing);
    const empty_valid = empty.Size == 0 and fixture.device.ReadCalls == read_calls;
    if (!efi.buffer.releasePool(&fixture.services, &backing)) verify.failure(error.ReleaseFailed);

    if (!reader.deinitialize()) verify.failure(error.ReleaseFailed);
    verify.require(size_rejected and caller_bound and volume_rejected and volume_bound and exact and truncated and overlong and empty_valid and
        fixture.clean(), labels.FAT_UNIT_EXACT);
}

fn failures() void {
    for (1..3) |position| {
        fixture.reset();
        _ = encode(0, constants.BLOCK_BYTES);
        fixture.device.FailAllocation = position;
        verify.require(rejects(0, fixture.media.LastBlock, error.AllocationFailed) and fixture.device.AllocateCalls == position and
            fixture.device.FreeCalls == position - 1, labels.FAT_PRESSURE);
    }
    fixture.reset();
    _ = encode(0, constants.BLOCK_BYTES);
    fixture.device.FailLBA = 0;
    verify.require(rejects(0, fixture.media.LastBlock, error.ReadFailed) and fixture.device.ReadCalls == 1 and fixture.device.FreeCalls == 1, labels.FAT_READ_FAILURE);
}

fn geometry() void {
    fixture.reset();
    fixture.media.BlockSize = 0;
    verify.require(rejects(0, fixture.media.LastBlock, error.InvalidBootSector) and fixture.device.AllocateCalls == 0, labels.FAT_GEOMETRY);
    fixture.reset();
    encode(0, constants.BLOCK_BYTES).TotalSectors32 = 0;
    const empty = rejects(0, fixture.media.LastBlock, error.InvalidBootSector);
    fixture.reset();
    encode(0, constants.BLOCK_BYTES).FatSize32 = std.math.maxInt(u32);
    const overflowing = rejects(0, fixture.media.LastBlock, error.InvalidBootSector);
    fixture.reset();
    encode(0, constants.BLOCK_BYTES).ReservedSectors = 0;
    const overlaps_boot = rejects(0, fixture.media.LastBlock, error.InvalidBootSector);
    fixture.reset();
    encode(0, constants.BLOCK_BYTES).SectorsPerCluster = 3;
    const non_power_of_two = rejects(0, fixture.media.LastBlock, error.InvalidBootSector);
    fixture.reset();
    const boot_sector = encode(0, constants.BLOCK_BYTES);
    boot_sector.TotalSectors32 = constants.DISK_BLOCKS + 2;
    boot_sector.FatCount = 2;
    fixture.media.LastBlock = boot_sector.TotalSectors32 - 1;
    const short_fat_copy = rejects(0, fixture.media.LastBlock, error.InvalidBootSector) and fixture.device.ReadCalls == 1;
    verify.require(empty and overflowing and overlaps_boot and non_power_of_two and short_fat_copy, labels.FAT_GEOMETRY);
}

fn extents() !void {
    fixture.reset();
    const start = constants.PARTITION_FIRST_LBA;
    const boot_sector = encode(start, constants.BLOCK_BYTES);
    boot_sector.TotalSectors32 = 7;
    boot_sector.SectorsPerCluster = 2;
    const reversed = rejects(start, start - 1, error.InvalidPartition);
    const off_media = rejects(start, fixture.media.LastBlock + 1, error.InvalidPartition);
    verify.require(reversed and off_media and fixture.device.AllocateCalls == 0 and fixture.device.ReadCalls == 0, labels.FAT_EXTENT);
    const outside_partition = rejects(start, start + 5, error.InvalidBootSector);
    verify.require(outside_partition and fixture.device.ReadCalls == 1 and fixture.device.FreeCalls == 1, labels.FAT_EXTENT);

    const last_cluster = clusters.CLUSTER_DATA_START + 1;
    link(start, clusters.CLUSTER_DATA_START, last_cluster + 1);
    var reader = try mount(start, constants.PARTITION_LAST_LBA);
    defer if (!reader.deinitialize()) verify.failure(error.ReleaseFailed);
    try reader.readCluster(last_cluster);
    const off_volume_data = failedWith(reader.readCluster(last_cluster + 1), error.InvalidCluster);
    const off_volume_fat = failedWith(reader.getNextCluster(last_cluster + 1), error.InvalidCluster);
    const successor = failedWith(reader.getNextCluster(clusters.CLUSTER_DATA_START), error.InvalidCluster);
    const bounded_reads = fixture.device.ReadCalls == 4 and fixture.device.Reads[2].LBA == start + 4 and
        fixture.device.Reads[2].Bytes == 2 * constants.BLOCK_BYTES and fixture.device.Reads[3].LBA == start + 1 and
        fixture.device.Reads[3].Bytes == constants.BLOCK_BYTES;
    if (!reader.deinitialize()) verify.failure(error.ReleaseFailed);
    verify.require(off_volume_data and off_volume_fat and successor and bounded_reads and fixture.clean(), labels.FAT_EXTENT);
}

fn directoryChains() !void {
    const first_cluster = clusters.CLUSTER_DATA_START;
    const second_cluster = first_cluster + 1;
    for ([_]u32{ first_cluster, second_cluster }) |first_link| {
        fixture.reset();
        _ = encode(0, constants.BLOCK_BYTES);
        @memset(sector(2), format.constants.entries.ENTRY_FREE);
        @memset(sector(3), format.constants.entries.ENTRY_FREE);
        link(0, first_cluster, first_link);
        link(0, second_cluster, first_cluster);
        var reader = try mount(0, fixture.media.LastBlock);
        defer if (!reader.deinitialize()) verify.failure(error.ReleaseFailed);
        const cycle = failedWith(reader.findInStack(first_cluster, labels.FAT_MISSING_IDENTITY), error.InvalidChain);
        const maximum_reads: usize = if (first_link == first_cluster) 3 else 7;
        if (!reader.deinitialize()) verify.failure(error.ReleaseFailed);
        verify.require(cycle and fixture.device.ReadCalls <= maximum_reads and fixture.clean(), labels.FAT_DIRECTORY);
    }

    fixture.reset();
    _ = encode(0, constants.BLOCK_BYTES);
    @memset(sector(2), format.constants.entries.ENTRY_FREE);
    link(0, first_cluster, second_cluster);
    const entry: *StackEntry = @ptrCast(@alignCast(sector(3).ptr));
    entry.* = std.mem.zeroes(StackEntry);
    entry.Identity = .{ 'U', 'N', 'I', 'T', ' ', ' ', ' ', ' ' };
    entry.Extension = .{ 'B', 'I', 'N' };
    entry.setFirstCluster(second_cluster + 1);
    entry.UnitSize = constants.UNIT_PAYLOAD.len;
    var reader = try mount(0, fixture.media.LastBlock);
    defer if (!reader.deinitialize()) verify.failure(error.ReleaseFailed);
    const found = try reader.openLocation(labels.FAT_UNIT_IDENTITY);
    const marker = try reader.findInStack(first_cluster, labels.FAT_MISSING_IDENTITY);
    const marker_without_fat = fixture.device.ReadCalls == 7;
    @memset(sector(3), format.constants.entries.ENTRY_FREE);
    link(0, second_cluster, clusters.CLUSTER_EOC);
    const end = try reader.findInStack(first_cluster, labels.FAT_MISSING_IDENTITY);
    if (!reader.deinitialize()) verify.failure(error.ReleaseFailed);
    verify.require(found.UnitSize == constants.UNIT_PAYLOAD.len and found.getFirstCluster() == second_cluster + 1 and marker == null and
        marker_without_fat and end == null and fixture.device.ReadCalls == 11 and fixture.clean(), labels.FAT_DIRECTORY);
}

fn failedWith(result: anytype, expected: anyerror) bool {
    if (result) |_| return false else |failure| return failure == expected;
}

fn rejectsAllocated(reader: *fat.Reader, entry: *const StackEntry, maximum: u32, expected: anyerror) bool {
    var backing: efi.types.buffer.PoolClaim = .{};
    const refused = if (reader.readUnitToAllocated(entry, maximum, &backing)) |_| false else |failure| failure == expected;
    return efi.buffer.releasePool(&fixture.services, &backing) and refused;
}

fn mount(start_lba: u64, end_lba: u64) !fat.Reader {
    var reader: fat.Reader = .{ .BootServices = &fixture.services };
    errdefer if (!reader.deinitialize()) verify.failure(error.ReleaseFailed);
    try reader.initialize(&fixture.protocol, start_lba, end_lba);
    return reader;
}

fn rejects(start_lba: u64, end_lba: u64, expected: anyerror) bool {
    var reader = mount(start_lba, end_lba) catch |failure|
        return failure == expected and fixture.clean();
    if (!reader.deinitialize()) verify.failure(error.ReleaseFailed);
    return false;
}

fn encode(start_lba: u64, sector_bytes: u16) *BootSector {
    const boot_sector: *BootSector = @ptrCast(@alignCast(sector(start_lba).ptr));
    boot_sector.* = std.mem.zeroes(BootSector);
    boot_sector.BytesPerSector = sector_bytes;
    boot_sector.SectorsPerCluster = 1;
    boot_sector.ReservedSectors = 1;
    boot_sector.FatCount = 1;
    boot_sector.TotalSectors32 = @intCast(constants.DISK_BLOCKS - start_lba);
    boot_sector.FatSize32 = 1;
    boot_sector.RootCluster = clusters.CLUSTER_DATA_START;
    boot_sector.Signature = format.constants.magic.BOOT_SIGNATURE;
    return boot_sector;
}

fn link(start_lba: u64, cluster_number: u32, successor: u32) void {
    fixture.writeU32(sector(start_lba + 1), @as(usize, cluster_number) * @sizeOf(u32), successor);
}

fn sector(lba: u64) []u8 {
    return fixture.device.Disk[@as(usize, @intCast(lba)) * constants.BLOCK_BYTES ..][0..constants.BLOCK_BYTES];
}
