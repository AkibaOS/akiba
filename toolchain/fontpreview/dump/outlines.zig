//! Outline Dump

const std = @import("std");

const font = @import("shared").font;
const preview = @import("fontpreview");

const Face = font.types.face.Face;
const GlyphBuffer = font.types.outline.GlyphBuffer;

const messages = preview.strings.messages;

pub fn emit(allocator: std.mem.Allocator, data: []const u8) !void {
    const face = try font.face.load(data);
    var buffer = GlyphBuffer.initAllocating(allocator);
    defer buffer.deinit();

    std.debug.print(messages.FACE, .{
        face.UnitsPerEm,
        face.GlyphCount,
        face.Ascender,
        face.Descender,
        face.LineGap,
    });

    var codepoint: u32 = 0x20;
    while (codepoint <= 0x7E) : (codepoint += 1) {
        try emitGlyph(&face, codepoint, &buffer);
    }

    for ([_]u32{ 0x00A9, 0x30A2, 0x30AD, 0x30D0 }) |extra| {
        try emitGlyph(&face, extra, &buffer);
    }
}

fn emitGlyph(face: *const Face, codepoint: u32, buffer: *GlyphBuffer) !void {
    const glyph_id = try font.charmap.lookupFace(face, codepoint);
    if (glyph_id == 0) return;

    try font.outline.load(face, glyph_id, buffer);
    const advance = try font.metrics.advanceWidth(face, glyph_id);

    std.debug.print(messages.GLYPH, .{
        codepoint,
        glyph_id,
        advance,
        buffer.Shape.ContourCount,
        buffer.Shape.PointCount,
    });

    for (0..buffer.Shape.ContourCount) |contour| {
        const range = buffer.Shape.contourRange(contour);
        std.debug.print(messages.CONTOUR, .{ contour, range.Start, range.End });

        for (buffer.Shape.Points[range.Start .. range.End + 1]) |point| {
            std.debug.print(messages.POINT, .{ point.X, point.Y, @intFromBool(point.OnCurve) });
        }
    }
}
