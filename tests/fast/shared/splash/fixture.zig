//! Splash Regression Canvas And Region Checks

const std = @import("std");

const constants = @import("tests").fast.constants.render;
const font = @import("shared").font;
const graphics = @import("shared").graphics;
const splash = @import("shared").splash;
const types = @import("tests").fast.types.render;

const Canvas = splash.types.canvas.Canvas;
const Face = font.types.face.Face;
const GuardedFrame = types.GuardedFrame;
const Surface = graphics.types.surface.Surface;
const TextRenderer = graphics.types.renderer.TextRenderer;

pub fn canvas(surface: Surface, face: Face, renderer: *TextRenderer) Canvas {
    var result = Canvas.initialize(surface, face, renderer).?;
    result.RuleX = constants.RULE_X;
    result.RuleY = constants.RULE_Y;
    result.TrailBaseline = constants.TRAIL_BASELINE;
    return result;
}

pub fn expectOutsideRect(actual: *const GuardedFrame, expected: *const GuardedFrame, x: i32, y: i32, width: i32, height: i32) !void {
    for (0..constants.FRAME_HEIGHT) |row| {
        for (0..constants.FRAME_WIDTH) |column| {
            const inside = @as(i32, @intCast(column)) >= x and @as(i32, @intCast(column)) < x + width and
                @as(i32, @intCast(row)) >= y and @as(i32, @intCast(row)) < y + height;
            if (!inside) {
                const offset = row * constants.FRAME_STRIDE + column;
                try std.testing.expectEqual(expected.Pixels[offset], actual.Pixels[offset]);
            }
        }
    }
}

pub fn expectRectEqual(actual: *const GuardedFrame, expected: *const GuardedFrame, x: i32, y: i32, width: i32, height: i32) !void {
    var row = y;
    while (row < y + height) : (row += 1) {
        var column = x;
        while (column < x + width) : (column += 1) {
            const offset = @as(usize, @intCast(row)) * constants.FRAME_STRIDE + @as(usize, @intCast(column));
            try std.testing.expectEqual(expected.Pixels[offset], actual.Pixels[offset]);
        }
    }
}
