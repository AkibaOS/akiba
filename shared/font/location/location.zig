//! Glyph Location Table Validation and Lookup

const font = @import("shared").font;
const sfnt = @import("shared").sfnt;

const Face = font.types.face.font.Face;
const FontError = font.errors.font.FontError;
const GlyphBounds = font.types.bounds.GlyphBounds;
const Reader = sfnt.types.reader.Reader;

pub fn validate(loca: []const u8, format: i16, glyph_count: u16, glyf_length: usize) FontError!void {
    const size = try entrySize(format);
    const entries = @as(usize, glyph_count) + 1;
    if (entries > loca.len / size) return FontError.UnexpectedEnd;

    var reader = Reader.initialize(loca);
    var previous: usize = 0;
    for (0..entries) |_| {
        const offset = try readOffset(&reader, size);
        if (offset < previous) return FontError.InvalidLocations;
        if (offset > glyf_length) return FontError.TableOutOfBounds;
        previous = offset;
    }
}

pub fn bounds(face: *const Face, glyph_id: u16) FontError!GlyphBounds {
    if (glyph_id >= face.GlyphCount) return FontError.GlyphOutOfRange;

    const size = try entrySize(face.IndexToLocationFormat);
    var reader = Reader.initialize(face.Loca);
    try reader.seek(@as(usize, glyph_id) * size);
    const start = try readOffset(&reader, size);
    const end = try readOffset(&reader, size);
    if (end < start) return FontError.InvalidLocations;
    if (end > face.Glyf.len) return FontError.TableOutOfBounds;
    return .{ .Start = start, .End = end };
}

fn entrySize(format: i16) FontError!usize {
    return switch (format) {
        0 => @sizeOf(u16),
        1 => @sizeOf(u32),
        else => FontError.InvalidLocations,
    };
}

fn readOffset(reader: *Reader, size: usize) FontError!usize {
    if (size == @sizeOf(u16)) return @as(usize, try reader.readU16()) * 2;
    return try reader.readU32();
}
