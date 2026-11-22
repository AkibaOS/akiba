//! GPT Sector Delivery And Completion Regressions

const std = @import("std");

const fixture = @import("tests").fast.gpt.fixture;
const layout = @import("tests").fast.constants.gpt.layout;
const shared = @import("shared");

const Disk = @import("tests").fast.types.gpt.disk.Disk;
const Source = @import("tests").fast.types.gpt.source.Source;
const Volume = shared.boot.types.volume.Volume;
const identity = shared.gpt.read.identity;

pub fn discoversVolume() !void {
    var disk = wideFixture();
    const last = layout.ENTRY_BYTES * (layout.STREAM_ENTRY_COUNT - 1);
    @memcpy(disk.Table[last..][0..layout.ENTRY_PREFIX_BYTES], disk.Table[0..layout.ENTRY_PREFIX_BYTES]);
    @memset(disk.Table[0..layout.ENTRY_PREFIX_BYTES], 0);
    fixture.seal(&disk, layout.STREAM_TABLE_BYTES);
    var source: Source = .{ .Disk = &disk };
    try std.testing.expectEqualDeep(fixture.volume(), (try discover(&source)).?);
    try expectWindow(&source);
    source.Count = 0;
    @memcpy(disk.Table[0..layout.ENTRY_PREFIX_BYTES], disk.Table[last..][0..layout.ENTRY_PREFIX_BYTES]);
    disk.Table[16] ^= 1;
    fixture.seal(&disk, layout.STREAM_TABLE_BYTES);
    try std.testing.expectError(error.AmbiguousPartition, discover(&source));
    source.Count = 0;
    disk.Table[layout.STREAM_TABLE_BYTES - 1] ^= 1;
    try std.testing.expectError(error.TableChecksum, discover(&source));
}

fn discover(source: *Source) !?Volume {
    var scratch: [layout.BLOCK_BYTES]u8 = undefined;
    return shared.gpt.read.select.firstAfs(.{ .Context = source, .Read = read, .BlockBytes = layout.BLOCK_BYTES, .LastLBA = layout.DISK_LAST_LBA }, &scratch);
}

pub fn splitEntry() !void {
    var disk = wideFixture();
    const last = layout.ENTRY_BYTES * (layout.STREAM_ENTRY_COUNT - 1);
    @memcpy(disk.Table[last..][0..layout.ENTRY_PREFIX_BYTES], disk.Table[0..layout.ENTRY_PREFIX_BYTES]);
    @memset(disk.Table[0..layout.ENTRY_PREFIX_BYTES], 0);
    @memset(disk.Table[layout.STREAM_TABLE_BYTES..], 0xa7);
    fixture.seal(&disk, layout.STREAM_TABLE_BYTES);
    var source: Source = .{ .Disk = &disk };
    try std.testing.expect(try match(fixture.volume(), &source));
    try expectWindow(&source);
}

pub fn headerRefusal() !void {
    var disk = wideFixture();
    var other = fixture.volume();
    other.DiskGUID[0] ^= 1;
    var source: Source = .{ .Disk = &disk };
    try std.testing.expect(!try match(other, &source));
    try expectPrimary(&source);
    source.Count = 0;
    std.mem.writeInt(u64, disk.Primary[layout.HEADER_TABLE_OFFSET..][0..@sizeOf(u64)], layout.FIRST_USABLE, .little);
    fixture.seal(&disk, layout.STREAM_TABLE_BYTES);
    try std.testing.expectError(error.InvalidTable, match(fixture.volume(), &source));
    try expectPrimary(&source);
    source.Count = 0;
    other = fixture.volume();
    other.DiskLastLBA -= 1;
    try std.testing.expect(!try match(other, &source));
    try std.testing.expectEqual(@as(usize, 0), source.Count);
}

pub fn lateRefusal() !void {
    var disk = wideFixture();
    var source: Source = .{ .Disk = &disk, .FailAt = layout.TABLE_LBA + 1 };
    try std.testing.expectError(error.EndOfStream, match(fixture.volume(), &source));
    try expectWindow(&source);
    source.Count = 0;
    source.FailAt = null;
    disk.Table[layout.STREAM_TABLE_BYTES - 1] ^= 1;
    try std.testing.expectError(error.TableChecksum, match(fixture.volume(), &source));
    try expectWindow(&source);
}

pub fn duplicateEntry() !void {
    var disk = wideFixture();
    const last = layout.ENTRY_BYTES * (layout.STREAM_ENTRY_COUNT - 1);
    @memcpy(disk.Table[last..][0..layout.ENTRY_PREFIX_BYTES], disk.Table[0..layout.ENTRY_PREFIX_BYTES]);
    fixture.seal(&disk, layout.STREAM_TABLE_BYTES);
    var source: Source = .{ .Disk = &disk };
    try std.testing.expectError(error.AmbiguousPartition, match(fixture.volume(), &source));
    try expectWindow(&source);
}

fn wideFixture() Disk {
    var disk = fixture.make();
    std.mem.writeInt(u32, disk.Primary[layout.HEADER_COUNT_OFFSET..][0..@sizeOf(u32)], layout.STREAM_ENTRY_COUNT, .little);
    fixture.seal(&disk, layout.STREAM_TABLE_BYTES);
    return disk;
}

fn match(volume: Volume, source: *Source) !bool {
    var scratch: [layout.BLOCK_BYTES]u8 = undefined;
    return identity.matchSectors(volume, .{
        .Context = source,
        .Read = read,
        .BlockBytes = layout.BLOCK_BYTES,
        .LastLBA = layout.DISK_LAST_LBA,
    }, &scratch);
}

fn read(context: *anyopaque, lba: u64, destination: []u8) !void {
    const source: *Source = @ptrCast(@alignCast(context));
    if (source.Count == source.Calls.len or destination.len != layout.BLOCK_BYTES) return error.TestUnexpectedResult;
    source.Calls[source.Count] = lba;
    source.Count += 1;
    if (source.FailAt == lba) return error.EndOfStream;
    if (lba == layout.PRIMARY_LBA) {
        @memcpy(destination, &source.Disk.Primary);
    } else if (lba >= layout.TABLE_LBA and lba < layout.TABLE_LBA + layout.STREAM_SECTORS) {
        const offset: usize = @intCast((lba - layout.TABLE_LBA) * layout.BLOCK_BYTES);
        @memcpy(destination, source.Disk.Table[offset..][0..layout.BLOCK_BYTES]);
    } else {
        return error.TestUnexpectedResult;
    }
}

fn expectPrimary(source: *const Source) !void {
    try std.testing.expectEqualSlices(u64, &.{layout.PRIMARY_LBA}, source.Calls[0..source.Count]);
}

fn expectWindow(source: *const Source) !void {
    try std.testing.expectEqualSlices(u64, &.{ layout.PRIMARY_LBA, layout.TABLE_LBA, layout.TABLE_LBA + 1 }, source.Calls[0..source.Count]);
}
