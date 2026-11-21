//! Display Rectangle And Pixel Packing Regressions

const std = @import("std");

const display = @import("shared").display;
const pixels = @import("display").raster.row;

const Mode = display.types.mode.Mode;
const Rectangle = display.types.rectangle.Rectangle;

const MODE: Mode = .{ .Width = 8, .Height = 4, .Stride = 12, .Format = .BGR };

test "display rectangles reject zero areas and every edge crossing" {
    const box: Rectangle = .{ .X = 2, .Y = 1, .Width = 3, .Height = 2 };
    try std.testing.expect(display.geometry.rectangle.contains(MODE, box));
    try std.testing.expectEqual(@as(?usize, 18), display.geometry.rectangle.inputBytes(box));
    try std.testing.expect(!display.geometry.rectangle.contains(MODE, .{ .X = 7, .Y = 1, .Width = 2, .Height = 1 }));
    try std.testing.expect(!display.geometry.rectangle.contains(MODE, .{ .X = 2, .Y = 3, .Width = 1, .Height = 2 }));
    try std.testing.expect(!display.geometry.rectangle.contains(MODE, .{ .X = 0, .Y = 0, .Width = 0, .Height = 1 }));
    try std.testing.expect(display.geometry.rectangle.inputBytes(.{
        .X = 0,
        .Y = 0,
        .Width = std.math.maxInt(u32),
        .Height = std.math.maxInt(u32),
    }) == null);
}

test "display rows honor real pitch, visible width, and actual mapped backing" {
    try std.testing.expectEqual(@as(?usize, 38), display.geometry.rectangle.rowOffset(MODE, 2, 3, 3, 48));
    try std.testing.expectEqual(@as(?usize, null), display.geometry.rectangle.rowOffset(MODE, 2, 3, 3, 40));
    try std.testing.expectEqual(@as(?usize, null), display.geometry.rectangle.rowOffset(MODE, 7, 1, 2, 48));
    try std.testing.expectEqual(@as(?usize, null), display.geometry.rectangle.rowOffset(MODE, 0, 4, 1, 48));
}

test "display conversion packs actual RGB and BGR bytes and rejects malformed rows before writing" {
    const rgb = [_]u8{ 0x11, 0x22, 0x44, 0x80, 0x30, 0x05 };
    var packed_row = [_]u32{ 0x17171717, 0x81818181 };
    try std.testing.expect(!pixels.pack(.RGB, rgb[0..5], &packed_row));
    try std.testing.expectEqualSlices(u32, &.{ 0x17171717, 0x81818181 }, &packed_row);
    try std.testing.expect(pixels.pack(.RGB, &rgb, &packed_row));
    try std.testing.expectEqualSlices(u32, &.{ 0x00442211, 0x00053080 }, &packed_row);
    try std.testing.expect(pixels.pack(.BGR, &rgb, &packed_row));
    try std.testing.expectEqualSlices(u32, &.{ 0x00112244, 0x00803005 }, &packed_row);
}
