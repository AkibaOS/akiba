//! Protective MBR Image Integration Checks

const std = @import("std");

const constants = @import("tests").fast.constants.image.fixtures;
const io = @import("tests").fast.image.io;

pub fn protectivePartition(file: std.fs.File) !void {
    var sector: [constants.SECTOR_BYTES]u8 = undefined;
    try io.readExact(file, 0, &sector);
    const entry = sector[constants.MBR_ENTRY..][0..constants.MBR_ENTRY_BYTES];
    try std.testing.expectEqual(@as(u8, 0), entry[0]);
    try std.testing.expectEqual(@as(u8, 0xEE), entry[4]);
    try std.testing.expectEqual(@as(u32, 1), std.mem.readInt(u32, entry[8..12], .little));
    try std.testing.expectEqual(@as(u32, 131071), std.mem.readInt(u32, entry[12..16], .little));
    try std.testing.expectEqualSlices(u8, &.{ 0x55, 0xAA }, sector[constants.MBR_SIGNATURE..]);
    try io.expectZeros(sector[constants.MBR_ENTRY + constants.MBR_ENTRY_BYTES .. constants.MBR_SIGNATURE]);
}
