//! CRC32 Regression Checks

const std = @import("std");

const checksum = @import("utils").crc.checksum;
const strings = @import("tests").fast.strings.utils.vectors;

pub fn knownTextVectors() !void {
    try std.testing.expectEqual(@as(u32, 0x00000000), checksum.calculate(strings.EMPTY));
    try std.testing.expectEqual(@as(u32, 0xcbf43926), checksum.calculate(strings.CRC_CHECK_INPUT));
    try std.testing.expectEqual(@as(u32, 0x414fa339), checksum.calculate(strings.CRC_PANGRAM_INPUT));
}

pub fn knownBinaryVectors() !void {
    const zeroes = [_]u8{0} ** 32;

    try std.testing.expectEqual(@as(u32, 0xd202ef8d), checksum.calculate(&.{0x00}));
    try std.testing.expectEqual(@as(u32, 0xff000000), checksum.calculate(&.{0xff}));
    try std.testing.expectEqual(@as(u32, 0x190a55ad), checksum.calculate(&zeroes));
}

pub fn boundedSlices() !void {
    try std.testing.expectEqual(@as(u32, 0xcbf43926), checksum.calculate(strings.CRC_FRAMED_INPUT[1..10]));
    try std.testing.expectEqual(@as(u32, 0), checksum.calculate(strings.CRC_FRAMED_INPUT[1..1]));
}
