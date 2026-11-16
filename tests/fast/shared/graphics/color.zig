//! Pixel Packing And Color Blend Regressions

const std = @import("std");

const constants = @import("tests").constants.render;
const graphics = @import("shared").graphics;

const Color = graphics.types.color.Color;

pub fn packingAndChannels() !void {
    const color = Color.rgb(0x12, 0x34, 0x56);
    try std.testing.expectEqual(@as(u32, 0x00563412), color.toPixel(.RGB));
    try std.testing.expectEqual(@as(u32, 0x00123456), color.toPixel(.BGR));
    try std.testing.expectEqualDeep(color, Color.fromPixel(0xA5563412, .RGB));
    try std.testing.expectEqualDeep(color, Color.fromPixel(0xA5123456, .BGR));
    try std.testing.expectEqual(@as(u32, 0x00123456), color.toPixel(.Unknown));
    try std.testing.expectEqualDeep(color, Color.fromPixel(0xA5123456, .Bitmask));
}

pub fn blendEndpointsAndDirections() !void {
    const background = constants.BLEND_BACKGROUND;
    const foreground = constants.BLEND_FOREGROUND;
    try std.testing.expectEqualDeep(background, background.blend(foreground, 0, 255));
    try std.testing.expectEqualDeep(foreground, background.blend(foreground, 255, 255));
    try std.testing.expectEqualDeep(Color.rgb(70, 80, 190), background.blend(foreground, 64, 255));
    try std.testing.expectEqualDeep(Color.rgb(120, 60, 140), background.blend(foreground, 128, 255));
}
