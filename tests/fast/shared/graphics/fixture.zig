//! Guarded Framebuffer Regression Storage

const std = @import("std");

const constants = @import("tests").constants.render;
const graphics = @import("shared").graphics;
const types = @import("tests").types.render;

const GuardedFrame = types.GuardedFrame;
const GuardedPixels = types.GuardedPixels;
const PixelFormat = graphics.types.pixel.PixelFormat;
const Surface = graphics.types.surface.Surface;

pub fn small(storage: *GuardedPixels, width: u32, height: u32, stride: u32, format: PixelFormat) Surface {
    @memset(&storage.Prefix, constants.GUARD_PIXEL);
    @memset(&storage.Pixels, constants.UNTOUCHED_PIXEL);
    @memset(&storage.Suffix, constants.GUARD_PIXEL);
    return Surface.initialize(@intFromPtr(&storage.Pixels), width, height, stride, format);
}

pub fn frame(storage: *GuardedFrame) Surface {
    @memset(&storage.Prefix, constants.GUARD_PIXEL);
    @memset(&storage.Pixels, constants.UNTOUCHED_PIXEL);
    @memset(&storage.Suffix, constants.GUARD_PIXEL);
    return Surface.initialize(@intFromPtr(&storage.Pixels), constants.FRAME_WIDTH, constants.FRAME_HEIGHT, constants.FRAME_STRIDE, .BGR);
}

pub fn expectSmallGuards(storage: *const GuardedPixels, surface: Surface) !void {
    try expectGuards(&storage.Prefix, &storage.Suffix);
    try expectPadding(&storage.Pixels, surface);
}

pub fn expectFrameGuards(storage: *const GuardedFrame, surface: Surface) !void {
    try expectGuards(&storage.Prefix, &storage.Suffix);
    try expectPadding(&storage.Pixels, surface);
}

fn expectGuards(prefix: []const u32, suffix: []const u32) !void {
    for (prefix) |pixel| try std.testing.expectEqual(constants.GUARD_PIXEL, pixel);
    for (suffix) |pixel| try std.testing.expectEqual(constants.GUARD_PIXEL, pixel);
}

fn expectPadding(pixels: []const u32, surface: Surface) !void {
    for (0..surface.Height) |row| {
        const start = row * surface.Stride + surface.Width;
        const end = (row + 1) * surface.Stride;
        for (pixels[start..end]) |pixel| try std.testing.expectEqual(constants.UNTOUCHED_PIXEL, pixel);
    }
    for (pixels[@as(usize, surface.Stride) * surface.Height ..]) |pixel| {
        try std.testing.expectEqual(constants.UNTOUCHED_PIXEL, pixel);
    }
}
