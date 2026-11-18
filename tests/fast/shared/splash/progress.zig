//! Splash Progress Rendering Regressions

const std = @import("std");

const canvases = @import("tests").fast.shared.splash.fixture;
const constants = @import("tests").constants.render;
const fixture = @import("tests").fast.shared.graphics.fixture;
const font = @import("shared").font;
const fonts = @import("tests").fast.shared.font.fixture;
const graphics = @import("shared").graphics;
const splash = @import("shared").splash;
const strings = @import("tests").strings.render;
const types = @import("tests").types.render;

const Canvas = splash.types.canvas.Canvas;
const GuardedFrame = types.GuardedFrame;
const SplashState = splash.types.state.SplashState;
const TextRenderer = graphics.types.renderer.TextRenderer;

const layout = splash.constants.layout;
const palette = splash.constants.palette;

pub fn boundedTargetWidths() !void {
    var state = SplashState.initialize(0);
    try std.testing.expectEqual(@as(i32, 0), splash.progress.targetWidth(&state));
    state.ProgressStep = 255;
    try std.testing.expectEqual(@as(i32, 0), splash.progress.targetWidth(&state));
    state = SplashState.initialize(2);
    try std.testing.expectEqual(@as(i32, 0), splash.progress.targetWidth(&state));
    state.ProgressStep = 1;
    try std.testing.expectEqual(@as(i32, 229), splash.progress.targetWidth(&state));
    state.ProgressStep = 2;
    try std.testing.expectEqual(@as(i32, 458), splash.progress.targetWidth(&state));
    state.ProgressStep = 255;
    try std.testing.expectEqual(@as(i32, 458), splash.progress.targetWidth(&state));
}

pub fn repaintAndFailurePalette() !void {
    const data = fonts.minimal();
    const face = try font.face.load(data.Data[0..data.Length]);
    const actual = try std.testing.allocator.create(GuardedFrame);
    defer std.testing.allocator.destroy(actual);
    const expected = try std.testing.allocator.create(GuardedFrame);
    defer std.testing.allocator.destroy(expected);
    var renderer = TextRenderer.initAllocating(std.testing.allocator);
    defer renderer.deinit();
    var canvas = canvases.canvas(fixture.frame(actual), face, &renderer);
    var reference = canvases.canvas(fixture.frame(expected), face, &renderer);
    splash.panel.fillBackground(&canvas);
    splash.panel.fillBackground(&reference);
    var state = SplashState.initialize(2);
    state.ProgressStep = 2;
    splash.progress.render(&canvas, &state);
    state.ProgressStep = 1;
    splash.progress.render(&canvas, &state);
    try expectBar(actual, expected, &canvas, 229, false);
    state.Failed = 1;
    splash.progress.render(&canvas, &state);
    try expectBar(actual, expected, &canvas, 229, true);
    state.ProgressTotal = 0;
    splash.progress.render(&canvas, &state);
    try expectBar(actual, expected, &canvas, 0, true);
    try fixture.expectFrameGuards(actual, canvas.Surface);
    try fixture.expectFrameGuards(expected, reference.Surface);
}

pub fn canvasCoverAndCentredText() !void {
    const data = fonts.minimal();
    const face = try font.face.load(data.Data[0..data.Length]);
    var storage: types.GuardedPixels = undefined;
    const surface = fixture.small(&storage, 40, 24, 44, .BGR);
    var renderer = TextRenderer.initAllocating(std.testing.allocator);
    defer renderer.deinit();
    var canvas = Canvas.initialize(surface, face, &renderer).?;
    var tall = surface;
    tall.Height = std.math.maxInt(u32);
    try std.testing.expect(Canvas.initialize(tall, face, &renderer) == null);
    var wide_stride = surface;
    wide_stride.Stride = std.math.maxInt(u32);
    try std.testing.expectEqual(2 * @as(usize, std.math.maxInt(u32)) + 1, wide_stride.offset(1, 2));
    try std.testing.expectEqual(@as(i32, 20), canvas.CentreX);
    try std.testing.expectEqual(@as(i32, 40), canvas.BackgroundWidth);
    try std.testing.expectEqual(@as(i32, 26), canvas.BackgroundHeight);
    try std.testing.expectEqual(@as(i32, 0), canvas.BackgroundOffsetX);
    try std.testing.expectEqual(@as(i32, 1), canvas.BackgroundOffsetY);
    try std.testing.expectEqual(@as(i32, 15), try splash.measure.centredOrigin(&canvas, .{ .PixelSize = 4, .Tracking = 2 }, strings.PAIR));
    try fixture.expectSmallGuards(&storage, surface);
}

fn expectBar(actual: *const GuardedFrame, background: *const GuardedFrame, canvas: *const Canvas, filled: i32, failed: bool) !void {
    try canvases.expectOutsideRect(actual, background, canvas.RuleX, canvas.RuleY, layout.RULE_WIDTH, layout.RULE_HEIGHT);
    var row: i32 = 0;
    while (row < layout.RULE_HEIGHT) : (row += 1) {
        var column: i32 = 0;
        while (column < layout.RULE_WIDTH) : (column += 1) {
            const border = row < 2 or row >= 30 or column < 2 or column >= 466;
            const fill = row >= 5 and row < 27 and column >= 5 and column < 5 + filled;
            const offset = @as(usize, @intCast(canvas.RuleY + row)) * constants.FRAME_STRIDE + @as(usize, @intCast(canvas.RuleX + column));
            const expected = if (border)
                (if (failed) palette.FRINGE_MAGENTA else palette.RULE_BORDER).toPixel(canvas.Surface.Format)
            else if (fill)
                (if (failed) palette.FRINGE_MAGENTA else palette.RULE_FILL).toPixel(canvas.Surface.Format)
            else
                background.Pixels[offset];
            try std.testing.expectEqual(expected, actual.Pixels[offset]);
        }
    }
}
