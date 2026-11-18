//! Dormant FAT Reader Initialization Boundary Regressions

const std = @import("std");

const constants = @import("tests").constants.acquisition;
const fat = @import("hikari").fs.types.fat32.reader;
const fixture = @import("tests").guest.hikari.disk.fixture;
const format = @import("shared").fat32.types.entry;
const labels = @import("tests").strings.acquisition;
const verify = @import("tests").verify;

pub fn run() !void {
    mismatch();
    try lifecycle();
    try unitFailure();
    failures();
    geometry();
}

fn mismatch() void {
    fixture.reset();
    fixture.media.IOAlign = 1;
    encode(constants.FAT_MISMATCH_BYTES);
    const rejected = if (fat.Reader.initialize(&fixture.protocol, &fixture.services, 0)) |_| false else |failure| failure == error.InvalidBootSector;
    verify.require(rejected, labels.FAT_SECTOR_MISMATCH);
    verify.require(fixture.clean(), labels.FAT_INITIALIZATION_RELEASE);
}

fn lifecycle() !void {
    fixture.reset();
    encode(constants.BLOCK_BYTES);
    fixture.writeU32(&fixture.device.Disk, constants.BLOCK_BYTES + 2 * @sizeOf(u32), 0x0FFFFFFF);
    var reader = try fat.Reader.initialize(&fixture.protocol, &fixture.services, 0);
    const aligned = @intFromPtr(reader.ClusterBuffer) % constants.IO_ALIGNMENT == 0 and
        @intFromPtr(reader.SectorBuffer) % constants.IO_ALIGNMENT == 0 and fixture.live() == 2;
    const terminal = try reader.getNextCluster(2);
    try reader.readCluster(2);
    reader.deinitialize();
    reader.deinitialize();
    verify.require(aligned and terminal == null and reader.BytesPerSector == constants.BLOCK_BYTES and
        reader.FatStartLBA == 1 and reader.DataStartLBA == 2 and fixture.clean(), labels.FAT_LIFECYCLE);
}

fn unitFailure() !void {
    fixture.reset();
    encode(constants.BLOCK_BYTES);
    var reader = try fat.Reader.initialize(&fixture.protocol, &fixture.services, 0);
    var entry: format.StackEntry = std.mem.zeroes(format.StackEntry);
    entry.FirstClusterLow = 2;
    entry.UnitSize = constants.UNIT_PAYLOAD.len;
    fixture.device.FailLBA = reader.DataStartLBA;
    const failed = if (reader.readUnitToAllocated(&entry)) |_| false else |failure| failure == error.ReadFailed;
    verify.require(failed and fixture.live() == 2, labels.FAT_UNIT_RELEASE);
    reader.deinitialize();
    verify.require(fixture.clean(), labels.FAT_INITIALIZATION_RELEASE);
}

fn failures() void {
    for (1..3) |position| {
        fixture.reset();
        encode(constants.BLOCK_BYTES);
        fixture.device.FailAllocation = position;
        verify.require(rejects(error.AllocationFailed) and fixture.device.AllocateCalls == position and
            fixture.device.FreeCalls == position - 1, labels.FAT_PRESSURE);
    }
    fixture.reset();
    encode(constants.BLOCK_BYTES);
    fixture.device.FailLBA = 0;
    verify.require(rejects(error.ReadFailed) and fixture.device.ReadCalls == 1 and fixture.device.FreeCalls == 1, labels.FAT_READ_FAILURE);
}

fn geometry() void {
    fixture.reset();
    fixture.media.BlockSize = 0;
    verify.require(rejects(error.InvalidBootSector) and fixture.device.AllocateCalls == 0, labels.FAT_GEOMETRY);
    fixture.reset();
    encode(constants.BLOCK_BYTES);
    fixture.writeU32(&fixture.device.Disk, 32, 0);
    const empty = rejects(error.InvalidBootSector);
    fixture.reset();
    encode(constants.BLOCK_BYTES);
    fixture.writeU32(&fixture.device.Disk, 36, std.math.maxInt(u32));
    const overflowing = rejects(error.InvalidBootSector);
    fixture.reset();
    encode(constants.BLOCK_BYTES);
    fixture.writeU32(&fixture.device.Disk, 32, constants.DISK_BLOCKS + 1);
    const outside = rejects(error.InvalidBootSector);
    fixture.reset();
    encode(constants.BLOCK_BYTES);
    fixture.device.Disk[13] = 3;
    verify.require(empty and overflowing and outside and rejects(error.InvalidBootSector), labels.FAT_GEOMETRY);
}

fn rejects(expected: anyerror) bool {
    var reader = fat.Reader.initialize(&fixture.protocol, &fixture.services, 0) catch |failure|
        return failure == expected and fixture.clean();
    reader.deinitialize();
    return false;
}

fn encode(sector_bytes: u16) void {
    const bytes = &fixture.device.Disk;
    std.mem.writeInt(u16, bytes[11..13], sector_bytes, .little);
    bytes[13] = 1;
    std.mem.writeInt(u16, bytes[14..16], 1, .little);
    bytes[16] = 1;
    fixture.writeU32(bytes, 32, constants.DISK_BLOCKS);
    fixture.writeU32(bytes, 36, 1);
    fixture.writeU32(bytes, 44, 2);
    std.mem.writeInt(u16, bytes[510..512], 0xAA55, .little);
}
