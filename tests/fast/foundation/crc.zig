//! CRC32 Regression Checks

const std = @import("std");

const strings = @import("tests").fast.strings.foundation.vectors;

pub fn knownTextVectors() !void {
    try std.testing.expectEqual(@as(u32, 0x00000000), std.hash.Crc32.hash(strings.EMPTY));
    try std.testing.expectEqual(@as(u32, 0xcbf43926), std.hash.Crc32.hash(strings.CRC_CHECK_INPUT));
    try std.testing.expectEqual(@as(u32, 0x414fa339), std.hash.Crc32.hash(strings.CRC_PANGRAM_INPUT));
}

pub fn knownBinaryVectors() !void {
    const zeroes = [_]u8{0} ** 32;

    try std.testing.expectEqual(@as(u32, 0xd202ef8d), std.hash.Crc32.hash(&.{0x00}));
    try std.testing.expectEqual(@as(u32, 0xff000000), std.hash.Crc32.hash(&.{0xff}));
    try std.testing.expectEqual(@as(u32, 0x190a55ad), std.hash.Crc32.hash(&zeroes));
}

pub fn boundedSlices() !void {
    try std.testing.expectEqual(@as(u32, 0xcbf43926), std.hash.Crc32.hash(strings.CRC_FRAMED_INPUT[1..10]));
    try std.testing.expectEqual(@as(u32, 0), std.hash.Crc32.hash(strings.CRC_FRAMED_INPUT[1..1]));
}
