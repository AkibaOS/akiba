//! FAT32 Entry Construction Checks

const std = @import("std");

const operations = @import("shared").fat32.write.entry;
const types = @import("shared").fat32.types.entry;

pub fn entryConstructionBytes() !void {
    const entry = operations.createEntry("longfilename", "extmore", 0x21, 0x12345678, 0x11223344);
    try std.testing.expectEqual(@as(usize, 32), @sizeOf(types.StackEntry));
    try std.testing.expectEqualSlices(u8, &("LONGFILE".* ++ "EXT".* ++ [_]u8{0x21} ++ [_]u8{0} ** 8 ++ [_]u8{ 0x34, 0x12 } ++ [_]u8{0} ** 4 ++ [_]u8{ 0x78, 0x56, 0x44, 0x33, 0x22, 0x11 }), std.mem.asBytes(&entry));
    const padded = operations.createEntry("go", "c", 0, 0, 0);
    try std.testing.expectEqualSlices(u8, "GO      ", &padded.Identity);
    try std.testing.expectEqualSlices(u8, "C  ", &padded.Extension);
}

pub fn markersAttributesAndClusters() !void {
    var entry = std.mem.zeroes(types.StackEntry);
    try std.testing.expect(entry.isEnd());
    try std.testing.expect(!entry.isFree());
    entry.Identity[0] = 0xe5;
    try std.testing.expect(entry.isFree());
    try std.testing.expect(!entry.isEnd());
    entry.Identity[0] = 0x05;
    try std.testing.expect(!entry.isFree());
    try std.testing.expect(!entry.isEnd());
    entry.Attributes = 0x0f;
    try std.testing.expect(entry.isLongIdentity());
    try std.testing.expect(entry.isVolumeId());
    try std.testing.expect(!entry.isStack());
    entry.Attributes = 0xcf;
    try std.testing.expect(entry.isLongIdentity());
    entry.Attributes = 0x1f;
    try std.testing.expect(!entry.isLongIdentity());
    try std.testing.expect(entry.isStack());
    try std.testing.expect(entry.isVolumeId());
    entry.Attributes = 0x20;
    try std.testing.expect(!entry.isLongIdentity());
    try std.testing.expect(!entry.isStack());
    try std.testing.expect(!entry.isVolumeId());
    entry.FirstClusterHigh = 0xabcd;
    entry.FirstClusterLow = 0x1234;
    try std.testing.expectEqual(@as(u32, 0xabcd1234), entry.getFirstCluster());
    entry.setFirstCluster(0x89abcdef);
    try std.testing.expectEqual(@as(u16, 0x89ab), entry.FirstClusterHigh);
    try std.testing.expectEqual(@as(u16, 0xcdef), entry.FirstClusterLow);
    try std.testing.expectEqualSlices(u8, &[_]u8{ 0xab, 0x89 }, std.mem.asBytes(&entry)[20..22]);
    try std.testing.expectEqualSlices(u8, &[_]u8{ 0xef, 0xcd }, std.mem.asBytes(&entry)[26..28]);
    try std.testing.expectEqual(@as(u32, 0x89abcdef), entry.getFirstCluster());
}

pub fn specializedEntries() !void {
    const stack = operations.createStackEntry("docs", 0x12345678);
    try std.testing.expectEqualSlices(u8, "DOCS    ", &stack.Identity);
    try std.testing.expectEqualSlices(u8, "   ", &stack.Extension);
    try std.testing.expectEqual(@as(u8, 0x10), stack.Attributes);
    try std.testing.expectEqual(@as(u32, 0x12345678), stack.getFirstCluster());
    try std.testing.expectEqual(@as(u32, 0), stack.UnitSize);
    const dot = operations.createDotEntry(7);
    try std.testing.expectEqualSlices(u8, ".       ", &dot.Identity);
    try std.testing.expect(dot.isStack());
    try std.testing.expectEqual(@as(u32, 7), dot.getFirstCluster());
    const parent = operations.createDotDotEntry(0);
    try std.testing.expectEqualSlices(u8, "..      ", &parent.Identity);
    try std.testing.expect(parent.isStack());
    try std.testing.expectEqual(@as(u32, 0), parent.getFirstCluster());
    const unit = operations.createUnitEntry("note", "txt", 9, 1234);
    try std.testing.expectEqualSlices(u8, "NOTE    ", &unit.Identity);
    try std.testing.expectEqualSlices(u8, "TXT", &unit.Extension);
    try std.testing.expectEqual(@as(u8, 0x20), unit.Attributes);
    try std.testing.expectEqual(@as(u32, 9), unit.getFirstCluster());
    try std.testing.expectEqual(@as(u32, 1234), unit.UnitSize);
}
