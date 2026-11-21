//! Check Display Geometry Before Computing Pixel Offsets

const std = @import("std");

const format = @import("shared").display.constants.format;

const Mode = @import("shared").display.types.mode.Mode;
const Rectangle = @import("shared").display.types.rectangle.Rectangle;

pub fn contains(mode: Mode, box: Rectangle) bool {
    return mode.isValid() and box.Width != 0 and box.Height != 0 and
        box.X < mode.Width and box.Y < mode.Height and
        box.Width <= mode.Width - box.X and box.Height <= mode.Height - box.Y;
}

pub fn inputBytes(box: Rectangle) ?usize {
    if (box.Width == 0 or box.Height == 0) return null;
    const pixels = std.math.mul(usize, box.Width, box.Height) catch return null;
    return std.math.mul(usize, pixels, format.RGB_BYTES) catch null;
}

pub fn rowOffset(mode: Mode, x: u32, y: u32, count: u32, backing_pixels: usize) ?usize {
    if (!contains(mode, .{ .X = x, .Y = y, .Width = count, .Height = 1 })) return null;
    const row = std.math.mul(usize, y, mode.Stride) catch return null;
    const offset = std.math.add(usize, row, x) catch return null;
    if (offset >= backing_pixels or count > backing_pixels - offset) return null;
    return offset;
}
