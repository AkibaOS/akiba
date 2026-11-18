//! Buffered Splash Trail And Failure Regressions

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

const GuardedFrame = types.GuardedFrame;
const SplashState = splash.types.state.SplashState;
const TextRenderer = graphics.types.renderer.TextRenderer;

const labels = splash.strings.splash;
const layout = splash.constants.layout;
const limits = splash.constants.limits;
const palette = splash.constants.palette;

pub fn activeToCompleteRepaint() !void {
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
    state.pushMessage(strings.LETTER);
    try splash.trail.render(&canvas, &state);
    const baseline = canvas.TrailBaseline + 2 * canvas.TrailStep;
    const marker_x = canvas.RuleX + layout.TRAIL_INSET;
    const marker_y = baseline - layout.ACTIVE_HEIGHT;
    const marker_offset = @as(usize, @intCast(marker_y)) * constants.FRAME_STRIDE + @as(usize, @intCast(marker_x));
    try std.testing.expectEqual(palette.TRAIL_CURRENT.toPixel(.BGR), actual.Pixels[marker_offset]);
    const status_x = canvas.RuleX + layout.RULE_WIDTH - layout.STATUS_WIDTH;
    reference.Surface.Width = @intCast(canvas.RuleX + layout.RULE_WIDTH);
    const style = splash.types.canvas.Canvas.styleFor(layout.TRAIL_SIZE, layout.TRAIL_TRACKING);
    try graphics.text.drawString(&renderer, &reference.Surface, &face, style, status_x, baseline, labels.STATUS_ACTIVITY[0..1], palette.TRAIL_CURRENT, null);
    try canvases.expectRectEqual(actual, expected, status_x, baseline - layout.TRAIL_SIZE, layout.STATUS_WIDTH, layout.TRAIL_SIZE + layout.TRAIL_DESCENT);
    try canvases.expectOutsideRect(actual, expected, canvas.RuleX, canvas.TrailBaseline - layout.TRAIL_SIZE, layout.RULE_WIDTH, @intCast(limits.TRAIL_BUFFER_HEIGHT));
    splash.panel.fillBackground(&reference);
    state.pushMessage(strings.SECOND_LETTER);
    try splash.trail.render(&canvas, &state);
    try std.testing.expectEqual(expected.Pixels[marker_offset], actual.Pixels[marker_offset]);
    try graphics.text.drawString(&renderer, &reference.Surface, &face, style, status_x, baseline, labels.STATUS_COMPLETE, palette.TRAIL_CURRENT, null);
    try canvases.expectRectEqual(actual, expected, status_x, baseline - layout.TRAIL_SIZE, layout.STATUS_WIDTH, layout.TRAIL_SIZE + layout.TRAIL_DESCENT);
    try fixture.expectFrameGuards(actual, canvas.Surface);
    reference.Surface.Width = constants.FRAME_WIDTH;
    try fixture.expectFrameGuards(expected, reference.Surface);
}

pub fn failedRowsRenderFailNotOK() !void {
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
    var state = SplashState.initialize(3);
    state.pushMessage(strings.LETTER);
    state.pushMessage(strings.LETTER);
    state.pushMessage(strings.LETTER);
    state.Failed = 1;
    try splash.trail.render(&canvas, &state);
    const style = splash.types.canvas.Canvas.styleFor(layout.TRAIL_SIZE, layout.TRAIL_TRACKING);
    const failed_x = canvas.RuleX + layout.RULE_WIDTH - 72;
    for (1..3) |index| {
        const baseline = canvas.TrailBaseline + canvas.TrailStep * @as(i32, @intCast(index));
        const offset = @as(usize, @intCast(baseline - layout.TRAIL_SIZE + 1)) * constants.FRAME_STRIDE + @as(usize, @intCast(failed_x));
        try std.testing.expect(actual.Pixels[offset] != expected.Pixels[offset]);
        try std.testing.expectEqual(palette.FRINGE_MAGENTA.toPixel(.BGR), actual.Pixels[offset]);
        try graphics.text.drawString(&renderer, &reference.Surface, &face, style, failed_x, baseline, labels.STATUS_FAILED, palette.FRINGE_MAGENTA, null);
        try canvases.expectRectEqual(actual, expected, failed_x, baseline - layout.TRAIL_SIZE, 72, layout.TRAIL_SIZE + layout.TRAIL_DESCENT);
    }
    const completed_x = canvas.RuleX + layout.RULE_WIDTH - layout.STATUS_WIDTH;
    try graphics.text.drawString(&renderer, &reference.Surface, &face, style, completed_x, canvas.TrailBaseline, labels.STATUS_COMPLETE, palette.TRAIL_COMPLETE, null);
    try canvases.expectRectEqual(actual, expected, completed_x, canvas.TrailBaseline - layout.TRAIL_SIZE, layout.STATUS_WIDTH, layout.TRAIL_SIZE + layout.TRAIL_DESCENT);
    try fixture.expectFrameGuards(actual, canvas.Surface);
    try fixture.expectFrameGuards(expected, reference.Surface);
}

pub fn malformedFontDoesNotCommitPartialTrail() !void {
    const data = fonts.minimal();
    const face = try font.face.load(data.Data[0..data.Length]);
    const actual = try std.testing.allocator.create(GuardedFrame);
    defer std.testing.allocator.destroy(actual);
    const before = try std.testing.allocator.create(GuardedFrame);
    defer std.testing.allocator.destroy(before);
    var renderer = TextRenderer.initAllocating(std.testing.allocator);
    defer renderer.deinit();
    var canvas = canvases.canvas(fixture.frame(actual), face, &renderer);
    splash.panel.fillBackground(&canvas);
    var state = SplashState.initialize(2);
    state.pushMessage(strings.LETTER);
    try splash.trail.render(&canvas, &state);
    before.* = actual.*;
    state = SplashState.initialize(2);
    state.pushMessage(strings.PAIR);
    state.Failed = 1;
    canvas.Face.Glyf = canvas.Face.Glyf[0..constants.RECTANGLE_GLYPH.len];
    try std.testing.expectError(error.TableOutOfBounds, splash.trail.render(&canvas, &state));
    try std.testing.expectEqualSlices(u32, &before.Pixels, &actual.Pixels);
    try fixture.expectFrameGuards(actual, canvas.Surface);
    try std.testing.expectError(error.TableOutOfBounds, splash.render.refresh(&canvas, &state));
    try canvases.expectOutsideRect(actual, before, canvas.RuleX, canvas.RuleY, layout.RULE_WIDTH, layout.RULE_HEIGHT);
    const border = @as(usize, @intCast(canvas.RuleY)) * constants.FRAME_STRIDE + @as(usize, @intCast(canvas.RuleX));
    try std.testing.expectEqual(palette.FRINGE_MAGENTA.toPixel(.BGR), actual.Pixels[border]);
    try fixture.expectFrameGuards(actual, canvas.Surface);
}

pub fn clippedTrailPreservesOutsidePixels() !void {
    const data = fonts.minimal();
    const face = try font.face.load(data.Data[0..data.Length]);
    const actual = try std.testing.allocator.create(GuardedFrame);
    defer std.testing.allocator.destroy(actual);
    const before = try std.testing.allocator.create(GuardedFrame);
    defer std.testing.allocator.destroy(before);
    var renderer = TextRenderer.initAllocating(std.testing.allocator);
    defer renderer.deinit();
    var canvas = canvases.canvas(fixture.frame(actual), face, &renderer);
    splash.panel.fillBackground(&canvas);
    before.* = actual.*;
    canvas.RuleX = -12;
    canvas.TrailBaseline = 10;
    var state = SplashState.initialize(1);
    state.pushMessage(strings.LETTER);
    try splash.trail.render(&canvas, &state);
    try canvases.expectOutsideRect(actual, before, -12, -8, layout.RULE_WIDTH, @intCast(limits.TRAIL_BUFFER_HEIGHT));
    const visible_message = @as(usize, 44) * constants.FRAME_STRIDE + 8;
    try std.testing.expect(actual.Pixels[visible_message] != before.Pixels[visible_message]);
    try fixture.expectFrameGuards(actual, canvas.Surface);
    canvas.RuleX = @intCast(constants.FRAME_WIDTH);
    before.* = actual.*;
    try splash.trail.render(&canvas, &state);
    try std.testing.expectEqualSlices(u32, &before.Pixels, &actual.Pixels);
}
