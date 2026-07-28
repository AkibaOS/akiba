//! Horizontal Metrics

const font = @import("shared").font;
const sfnt = @import("shared").sfnt;

const Face = font.types.face.Face;
const FontError = font.errors.font.FontError;
const GlyphMetrics = font.types.metrics.GlyphMetrics;
const Reader = sfnt.types.reader.Reader;

const LONG_METRIC_SIZE: usize = 4;

pub fn glyphMetrics(face: *const Face, glyph_id: u16) FontError!GlyphMetrics {
    if (glyph_id >= face.GlyphCount) {
        return FontError.GlyphOutOfRange;
    }
    if (face.LongMetricCount == 0) {
        return FontError.TableOutOfBounds;
    }

    var reader = Reader.initialize(face.Hmtx);

    if (glyph_id < face.LongMetricCount) {
        try reader.seek(@as(usize, glyph_id) * LONG_METRIC_SIZE);
        return GlyphMetrics{
            .AdvanceWidth = try reader.readU16(),
            .LeftSideBearing = try reader.readI16(),
        };
    }

    try reader.seek(@as(usize, face.LongMetricCount - 1) * LONG_METRIC_SIZE);
    const advance = try reader.readU16();

    const trailing = @as(usize, face.LongMetricCount) * LONG_METRIC_SIZE +
        @as(usize, glyph_id - face.LongMetricCount) * 2;
    try reader.seek(trailing);

    return GlyphMetrics{
        .AdvanceWidth = advance,
        .LeftSideBearing = try reader.readI16(),
    };
}

pub fn advanceWidth(face: *const Face, glyph_id: u16) FontError!u16 {
    const metrics = try glyphMetrics(face, glyph_id);
    return metrics.AdvanceWidth;
}
