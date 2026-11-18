//! Text Coverage Blending And Clipping Regressions

const std = @import("std");

const constants = @import("tests").constants.render;
const fixture = @import("tests").fast.shared.graphics.fixture;
const font = @import("shared").font;
const fonts = @import("tests").fast.shared.font.fixture;
const graphics = @import("shared").graphics;
const splash = @import("shared").splash;
const strings = @import("tests").strings.render;
const types = @import("tests").types.render;

const Color = graphics.types.color.Color;
const GuardedPixels = types.GuardedPixels;
const PixelFormat = graphics.types.pixel.PixelFormat;
const TextRenderer = graphics.types.renderer.TextRenderer;

pub fn coverageBlending() !void {
    const data = fonts.minimal();
    const face = try font.face.load(data.Data[0..data.Length]);
    const background = constants.BLEND_BACKGROUND;
    const foreground = constants.BLEND_FOREGROUND;
    var renderer = TextRenderer.initAllocating(std.testing.allocator);
    defer renderer.deinit();
    for ([_]PixelFormat{ .RGB, .BGR }) |format| {
        var storage: GuardedPixels = undefined;
        var surface = fixture.small(&storage, 3, 2, 5, format);
        graphics.draw.clear(&surface, background);
        try graphics.text.drawString(&renderer, &surface, &face, .{ .PixelSize = 1, .Tracking = 0 }, 0, 1, strings.LETTER, foreground, null);
        try std.testing.expectEqual(Color.rgb(120, 60, 140).toPixel(format), storage.Pixels[0]);
        try std.testing.expectEqual(background.toPixel(format), storage.Pixels[1]);
        try graphics.text.drawString(&renderer, &surface, &face, .{ .PixelSize = 1, .Tracking = 0 }, 0, 1, strings.LETTER, foreground, null);
        try std.testing.expectEqual(Color.rgb(170, 40, 90).toPixel(format), storage.Pixels[0]);
        try graphics.text.drawString(&renderer, &surface, &face, .{ .PixelSize = 1, .Tracking = 0 }, 0, 1, strings.LETTER, foreground, Color.rgb(0, 0, 0));
        try std.testing.expectEqual(Color.rgb(110, 10, 20).toPixel(format), storage.Pixels[0]);
        try fixture.expectSmallGuards(&storage, surface);
    }
}

pub fn clippedGlyphAndFontError() !void {
    const data = fonts.minimal();
    var face = try font.face.load(data.Data[0..data.Length]);
    var storage: GuardedPixels = undefined;
    var surface = fixture.small(&storage, 3, 2, 5, .BGR);
    var renderer = TextRenderer.initAllocating(std.testing.allocator);
    defer renderer.deinit();
    const background = constants.BLEND_BACKGROUND;
    const foreground = constants.BLEND_FOREGROUND;
    graphics.draw.clear(&surface, background);
    try graphics.text.drawString(&renderer, &surface, &face, .{ .PixelSize = 4, .Tracking = 0 }, -1, 2, strings.LETTER, foreground, null);
    for (0..2) |row| {
        try std.testing.expectEqual(foreground.toPixel(.BGR), storage.Pixels[row * 5]);
        try std.testing.expectEqual(background.toPixel(.BGR), storage.Pixels[row * 5 + 1]);
        try std.testing.expectEqual(background.toPixel(.BGR), storage.Pixels[row * 5 + 2]);
    }
    const before = storage.Pixels;
    face.Hmtx = &.{};
    try std.testing.expectError(error.UnexpectedEnd, graphics.text.drawString(&renderer, &surface, &face, .{ .PixelSize = 4, .Tracking = 0 }, 0, 1, strings.LETTER, foreground, null));
    try std.testing.expectEqualSlices(u32, &before, &storage.Pixels);
    try fixture.expectSmallGuards(&storage, surface);
}

pub fn embeddedTextIntegration() !void {
    const face = try font.face.load(graphics.assets.font.HIKARI);
    var storage: GuardedPixels = undefined;
    var surface = fixture.small(&storage, 32, 24, 36, .BGR);
    var renderer = TextRenderer.initAllocating(std.testing.allocator);
    defer renderer.deinit();
    const background = Color.rgb(0, 0, 0);
    graphics.draw.clear(&surface, background);
    try graphics.text.drawString(&renderer, &surface, &face, .{ .PixelSize = 16, .Tracking = 0 }, 1, 18, strings.REAL_FACE, Color.rgb(255, 255, 255), null);
    var changed: usize = 0;
    var antialiased: usize = 0;
    for (0..surface.Height) |row| {
        for (0..surface.Width) |column| {
            const pixel = storage.Pixels[row * surface.Stride + column];
            if (pixel != 0) changed += 1;
            if (pixel != 0 and pixel != 0x00FFFFFF) antialiased += 1;
        }
    }
    try std.testing.expect(changed > 0);
    try std.testing.expect(antialiased > 0);
    try fixture.expectSmallGuards(&storage, surface);

    const boot_storage = try std.testing.allocator.create(splash.types.workspace.Workspace);
    defer std.testing.allocator.destroy(boot_storage);
    var boot_renderer = boot_storage.bind();
    var reference: GuardedPixels = undefined;
    var reference_surface = fixture.small(&reference, 32, 24, 36, .BGR);
    graphics.draw.clear(&reference_surface, background);
    try graphics.text.drawString(&boot_renderer, &reference_surface, &face, .{ .PixelSize = 16, .Tracking = 0 }, 1, 18, strings.REAL_FACE, Color.rgb(255, 255, 255), null);
    try std.testing.expectEqualSlices(u32, &storage.Pixels, &reference.Pixels);
}
