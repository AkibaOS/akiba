//! Text Measurement

const font = @import("shared").font;
const raster = @import("shared").raster;
const typeset = @import("shared").typeset;

const utf8 = @import("utils").text.utf8;

const Face = font.types.face.Face;
const FontError = font.errors.font.FontError;
const TextStyle = typeset.types.style.TextStyle;

const limits = raster.constants.limits;

pub fn advanceWidth(face: *const Face, style: TextStyle, text: []const u8) FontError!i32 {
    const scale = face.scaleFor(style.PixelSize);

    var total: i32 = 0;
    var count: i32 = 0;
    var offset: usize = 0;

    while (offset < text.len) {
        const decoded = utf8.decode(text[offset..]);
        offset += decoded.Length;

        const glyph_id = try font.charmap.lookup(face.Charmap, decoded.Codepoint);
        const advance = try font.metrics.advanceWidth(face, glyph_id);
        total += scale.applyToUnits(@intCast(advance)).Raw;
        count += 1;
    }

    if (count > 1) {
        total += style.Tracking * limits.ONE_PIXEL * (count - 1);
    }

    return @divTrunc(total, limits.ONE_PIXEL);
}

pub fn ascent(face: *const Face, pixel_size: i32) i32 {
    return @divTrunc(@as(i32, face.Ascender) * pixel_size, @as(i32, face.UnitsPerEm));
}
