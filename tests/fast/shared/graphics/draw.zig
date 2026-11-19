//! Clipped Strided Drawing And Overlap Regressions

const std = @import("std");

const constants = @import("tests").fast.constants.render;
const fixture = @import("tests").fast.shared.graphics.fixture;
const graphics = @import("shared").graphics;
const types = @import("tests").fast.types.render;

const Color = graphics.types.color.Color;
const GuardedPixels = types.GuardedPixels;

pub fn clippedRectanglesAndClear() !void {
    var storage: GuardedPixels = undefined;
    var surface = fixture.small(&storage, 4, 3, 6, .RGB);
    const color = Color.rgb(0x12, 0x34, 0x56);
    graphics.draw.fillRect(&surface, -2, -1, 5, 3, color);
    graphics.draw.putPixel(&surface, -1, 0, color);
    graphics.draw.putPixel(&surface, 0, -1, color);
    graphics.draw.putPixel(&surface, 4, 0, color);
    graphics.draw.putPixel(&surface, 0, 3, color);
    graphics.draw.fillRect(&surface, 1, 1, 0, 2, color);
    graphics.draw.fillRect(&surface, 0, 0, -1, -1, color);
    for (0..3) |row| {
        for (0..4) |column| {
            const expected = if (row < 2 and column < 3) @as(u32, 0x00563412) else constants.UNTOUCHED_PIXEL;
            try std.testing.expectEqual(expected, storage.Pixels[row * 6 + column]);
        }
    }
    graphics.draw.putPixel(&surface, 3, 2, color);
    try std.testing.expectEqual(@as(u32, 0x00563412), storage.Pixels[15]);
    graphics.draw.clear(&surface, color);
    for (0..3) |row| {
        for (0..4) |column| try std.testing.expectEqual(@as(u32, 0x00563412), storage.Pixels[row * 6 + column]);
    }
    try fixture.expectSmallGuards(&storage, surface);
}

pub fn clippedStripedQuad() !void {
    var storage: GuardedPixels = undefined;
    var surface = fixture.small(&storage, 4, 4, 6, .BGR);
    graphics.draw.fillQuad(&surface, .{
        .{ .X = -1, .Y = -1 },
        .{ .X = 3, .Y = -1 },
        .{ .X = 3, .Y = 3 },
        .{ .X = -1, .Y = 3 },
    }, Color.rgb(0x12, 0x34, 0x56), .{ .Period = 2, .Gap = 1 });
    for (0..4) |row| {
        for (0..4) |column| {
            const expected = if (row == 1) @as(u32, 0x00123456) else constants.UNTOUCHED_PIXEL;
            try std.testing.expectEqual(expected, storage.Pixels[row * 6 + column]);
        }
    }
    try fixture.expectSmallGuards(&storage, surface);
}

pub fn overlappingCopies() !void {
    try expectCopy(0, 0, 1, 1, 4, 3);
    try expectCopy(1, 1, 0, 0, 4, 3);
    try expectCopy(0, 1, 1, 1, 4, 1);
    try expectCopy(1, 1, 0, 1, 4, 1);
    try expectCopy(0, 0, 0, 0, 5, 4);
}

fn expectCopy(source_x: u32, source_y: u32, destination_x: u32, destination_y: u32, width: u32, height: u32) !void {
    var storage: GuardedPixels = undefined;
    var surface = fixture.small(&storage, 5, 4, 7, .BGR);
    for (0..4) |row| {
        for (0..5) |column| storage.Pixels[row * 7 + column] = @intCast(row * 10 + column + 1);
    }
    const before = storage.Pixels;
    graphics.draw.copyRect(&surface, source_x, source_y, destination_x, destination_y, width, height);
    for (0..4) |row| {
        for (0..5) |column| {
            const moved = row >= destination_y and row < destination_y + height and column >= destination_x and column < destination_x + width;
            const expected = if (moved)
                before[(source_y + row - destination_y) * 7 + source_x + column - destination_x]
            else
                before[row * 7 + column];
            try std.testing.expectEqual(expected, storage.Pixels[row * 7 + column]);
        }
    }
    try fixture.expectSmallGuards(&storage, surface);
}
