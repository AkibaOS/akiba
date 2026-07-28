//! Outline Dump

const std = @import("std");

const font = @import("shared").font;

const strings = @import("fontpreview").strings;

const GlyphBuffer = font.types.outline.GlyphBuffer;

const messages = strings.messages;

var buffer: GlyphBuffer = undefined;

pub fn emit(data: []const u8) !void {
    const face = try font.face.load(data);

    std.debug.print(messages.FACE, .{
        face.UnitsPerEm,
        face.GlyphCount,
        face.Ascender,
        face.Descender,
        face.LineGap,
    });

    var codepoint: u32 = 0x20;
    while (codepoint <= 0x7E) : (codepoint += 1) {
        try emitGlyph(&face, codepoint);
    }

    for ([_]u32{ 0x00A9, 0x30A2, 0x30AD, 0x30D0 }) |extra| {
        try emitGlyph(&face, extra);
    }
}

fn emitGlyph(face: *const font.types.face.Face, codepoint: u32) !void {
    const glyph_id = try font.charmap.lookup(face.Charmap, codepoint);
    if (glyph_id == 0) {
        return;
    }

    try font.outline.load(face, glyph_id, &buffer);
    const advance = try font.metrics.advanceWidth(face, glyph_id);

    std.debug.print(messages.GLYPH, .{
        codepoint,
        glyph_id,
        advance,
        buffer.Shape.ContourCount,
        buffer.Shape.PointCount,
    });

    var contour: u16 = 0;
    while (contour < buffer.Shape.ContourCount) : (contour += 1) {
        const range = buffer.Shape.contourRange(contour);
        std.debug.print(messages.CONTOUR, .{ contour, range.Start, range.End });

        var index = range.Start;
        while (index <= range.End) : (index += 1) {
            const point = buffer.Shape.Points[index];
            std.debug.print(messages.POINT, .{ point.X, point.Y, @intFromBool(point.OnCurve) });
        }
    }
}
