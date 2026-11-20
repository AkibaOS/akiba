//! Console Geometry Controls And Scroll Regressions

const std = @import("std");

const fixture = @import("tests").fast.graphics.fixture;
const font = @import("shared").font;
const fonts = @import("tests").fast.font.fixture;
const graphics = @import("shared").graphics;
const strings = @import("tests").fast.strings.render;
const types = @import("tests").fast.types.render;

const Color = graphics.types.color.Color;
const Console = graphics.types.console.Console;
const GuardedPixels = types.GuardedPixels;
const TextRenderer = graphics.types.renderer.TextRenderer;

pub fn geometryControlsAndWrap() !void {
    const data = fonts.minimal();
    const face = try font.face.load(data.Data[0..data.Length]);
    var storage: GuardedPixels = undefined;
    var surface = fixture.small(&storage, 16, 12, 18, .BGR);
    var renderer = TextRenderer.initAllocating(std.testing.allocator);
    defer renderer.deinit();
    var console = try Console.initialize(&surface, &face, &renderer, 4);
    try std.testing.expectEqual(@as(i32, 4), console.CellWidth);
    try std.testing.expectEqual(@as(i32, 4), console.CellHeight);
    try std.testing.expectEqual(@as(i32, 3), console.Baseline);
    try std.testing.expectEqual(@as(u32, 4), console.Columns);
    try std.testing.expectEqual(@as(u32, 3), console.Rows);
    console.setColors(Color.rgb(255, 255, 255), Color.rgb(0, 0, 0));
    console.clearScreen();
    console.print(strings.CONSOLE_CONTROLS);
    try std.testing.expectEqual(@as(u32, 0), console.CursorColumn);
    try std.testing.expectEqual(@as(u32, 1), console.CursorRow);
    try std.testing.expectEqual(@as(u32, 0x00FFFFFF), storage.Pixels[0]);
    try std.testing.expectEqual(@as(u32, 0), storage.Pixels[1]);
    console.setCursor(3, 1);
    console.putChar('A');
    try std.testing.expectEqual(@as(u32, 0), console.CursorColumn);
    try std.testing.expectEqual(@as(u32, 2), console.CursorRow);
    console.putChar('\r');
    console.putChar(graphics.constants.console.BACKSPACE);
    try std.testing.expectEqual(@as(u32, 0), console.CursorColumn);
    try fixture.expectSmallGuards(&storage, surface);
}

pub fn scrollAndClearing() !void {
    const data = fonts.minimal();
    const face = try font.face.load(data.Data[0..data.Length]);
    var storage: GuardedPixels = undefined;
    var surface = fixture.small(&storage, 16, 12, 18, .BGR);
    var renderer = TextRenderer.initAllocating(std.testing.allocator);
    defer renderer.deinit();
    var console = try Console.initialize(&surface, &face, &renderer, 4);
    const background = Color.rgb(7, 8, 9);
    console.setColors(Color.rgb(255, 255, 255), background);
    graphics.draw.fillRect(&surface, 0, 0, 16, 4, Color.rgb(100, 0, 0));
    graphics.draw.fillRect(&surface, 0, 4, 16, 4, Color.rgb(0, 100, 0));
    graphics.draw.fillRect(&surface, 0, 8, 16, 4, Color.rgb(0, 0, 100));
    console.setCursor(2, 2);
    console.putChar('\n');
    try std.testing.expectEqual(@as(u32, 0), console.CursorColumn);
    try std.testing.expectEqual(@as(u32, 2), console.CursorRow);
    for (0..12) |row| {
        const expected: u32 = if (row < 4) 0x00006400 else if (row < 8) 0x00000064 else 0x00070809;
        for (0..16) |column| try std.testing.expectEqual(expected, storage.Pixels[row * 18 + column]);
    }
    const before = storage.Pixels;
    console.clearLine(console.Rows);
    try std.testing.expectEqualSlices(u32, &before, &storage.Pixels);
    console.clearLine(1);
    try std.testing.expectEqual(background.toPixel(.BGR), storage.Pixels[4 * 18]);
    try std.testing.expectEqual(@as(u32, 0x00006400), storage.Pixels[0]);
    console.clearScreen();
    try std.testing.expectEqual(@as(u32, 0), console.CursorColumn);
    try std.testing.expectEqual(@as(u32, 0), console.CursorRow);
    for (0..12) |row| {
        for (0..16) |column| try std.testing.expectEqual(background.toPixel(.BGR), storage.Pixels[row * 18 + column]);
    }
    try fixture.expectSmallGuards(&storage, surface);
}
