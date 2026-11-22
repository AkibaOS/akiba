//! Text Measurement

const std = @import("std");

const font = @import("shared").font;
const raster = @import("shared").raster;
const typeset = @import("shared").typeset;
const utf8 = @import("common").text.utf8;

const Face = font.types.face.font.Face;
const FontError = font.errors.font.FontError;
const TextStyle = typeset.types.style.TextStyle;

const limits = raster.constants.limits;

pub fn advanceWidth(face: *const Face, style: TextStyle, text: []const u8) FontError!i32 {
    const scale = try face.scaleFor(style.PixelSize);
    const tracking = @as(i64, style.Tracking) * limits.ONE_PIXEL;

    var total: i128 = 0;
    var offset: usize = 0;

    while (offset < text.len) {
        const decoded = utf8.decode(text[offset..]);
        const glyph_id = try font.charmap.lookupFace(face, decoded.Codepoint);
        const advance = try font.metrics.advanceWidth(face, glyph_id);
        if (offset != 0) total += tracking;
        total += scale.applyToUnitsRawWide(advance);
        offset += decoded.Length;
    }

    return std.math.cast(i32, @divTrunc(total, limits.ONE_PIXEL)) orelse FontError.MetricOutOfRange;
}

pub fn ascent(face: *const Face, pixel_size: i32) FontError!i32 {
    return face.pixelMetric(face.Ascender, pixel_size);
}
