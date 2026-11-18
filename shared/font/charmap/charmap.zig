//! Character To Glyph Mapping

const font = @import("shared").font;
const sfnt = @import("shared").sfnt;

const Face = font.types.face.Face;
const FontError = font.errors.font.FontError;
const Reader = sfnt.types.reader.Reader;
const SegmentLayout = font.types.charmap.SegmentLayout;

const constants = font.constants.charmap;

pub fn select(table: []const u8) FontError![]const u8 {
    return selectWithDomain(table, constants.GLYPH_DOMAIN_SIZE);
}

pub fn selectForFace(table: []const u8, glyph_count: u16) FontError![]const u8 {
    return selectWithDomain(table, glyph_count);
}

fn selectWithDomain(table: []const u8, glyph_domain: u32) FontError![]const u8 {
    var reader = Reader.initialize(table);
    if (try reader.readU16() != 0) return FontError.InvalidCharacterMap;
    const record_count = try reader.readU16();
    if (record_count > reader.remaining() / constants.ENCODING_RECORD_SIZE) return FontError.UnexpectedEnd;
    const records_end = reader.Offset + @as(usize, record_count) * constants.ENCODING_RECORD_SIZE;

    var best: ?[]const u8 = null;
    var best_rank: u8 = 0;
    var best_format: u16 = 0;

    for (0..record_count) |_| {
        const platform = try reader.readU16();
        const encoding = try reader.readU16();
        const offset = try reader.readU32();
        if (offset >= table.len) continue;
        if (offset < records_end) return FontError.InvalidCharacterMap;

        const subtable = table[offset..];
        var format_reader = Reader.initialize(subtable);
        const format = try format_reader.readU16();
        const rank = rankSubtable(platform, encoding, format);
        if (rank > best_rank) {
            best_rank = rank;
            best = subtable;
            best_format = format;
        }
    }

    return validate(best orelse return FontError.UnsupportedCharacterMap, best_format, glyph_domain);
}

fn rankSubtable(platform: u16, encoding: u16, format: u16) u8 {
    if (format == constants.FORMAT_SEGMENTED_COVERAGE) {
        if (platform == constants.PLATFORM_WINDOWS and encoding == constants.ENCODING_WINDOWS_FULL) return 4;
        if (platform == constants.PLATFORM_UNICODE) return 3;
    }
    if (format == constants.FORMAT_SEGMENT_MAPPING) {
        if (platform == constants.PLATFORM_WINDOWS and encoding == constants.ENCODING_WINDOWS_BMP) return 2;
        if (platform == constants.PLATFORM_UNICODE) return 1;
    }
    return 0;
}

pub fn lookupFace(face: *const Face, codepoint: u32) FontError!u16 {
    var reader = Reader.initialize(face.Charmap);
    const format = try reader.readU16();
    const id = try lookupValidated(try bounded(face.Charmap, format), format, codepoint);
    if (id >= face.GlyphCount) return FontError.GlyphOutOfRange;
    return id;
}

pub fn lookup(subtable: []const u8, codepoint: u32) FontError!u16 {
    var reader = Reader.initialize(subtable);
    const format = try reader.readU16();
    return lookupValidated(try validate(subtable, format, constants.GLYPH_DOMAIN_SIZE), format, codepoint);
}

fn bounded(subtable: []const u8, format: u16) FontError![]const u8 {
    var reader = Reader.initialize(subtable);
    try reader.skip(@sizeOf(u16));
    const length: usize = switch (format) {
        constants.FORMAT_SEGMENT_MAPPING => try reader.readU16(),
        constants.FORMAT_SEGMENTED_COVERAGE => coverage: {
            if (try reader.readU16() != 0) return FontError.InvalidCharacterMap;
            break :coverage try reader.readU32();
        },
        else => return FontError.UnsupportedCharacterMap,
    };
    const header_size = if (format == constants.FORMAT_SEGMENT_MAPPING) constants.SEGMENT_HEADER_SIZE else constants.COVERAGE_HEADER_SIZE;
    if (length < header_size or length > subtable.len) return FontError.UnexpectedEnd;
    return subtable[0..length];
}

fn validate(subtable: []const u8, format: u16, glyph_domain: u32) FontError![]const u8 {
    const data = try bounded(subtable, format);
    switch (format) {
        constants.FORMAT_SEGMENT_MAPPING => try validateSegments(data, glyph_domain),
        constants.FORMAT_SEGMENTED_COVERAGE => try validateGroups(data, glyph_domain),
        else => unreachable,
    }
    return data;
}

fn segmentLayout(reader: *Reader) FontError!SegmentLayout {
    const doubled_count = try readU16At(reader, constants.SEGMENT_COUNT_OFFSET);
    if (doubled_count == 0 or doubled_count % @sizeOf(u16) != 0) return FontError.InvalidCharacterMap;
    const array_size: usize = doubled_count;
    const end_codes = constants.SEGMENT_ENDS_OFFSET;
    const start_codes = end_codes + array_size + @sizeOf(u16);
    const deltas = start_codes + array_size;
    const range_offsets = deltas + array_size;
    const glyphs = range_offsets + array_size;
    if (glyphs > reader.Data.len) return FontError.UnexpectedEnd;
    return .{
        .Count = array_size / @sizeOf(u16),
        .EndCodes = end_codes,
        .StartCodes = start_codes,
        .Deltas = deltas,
        .RangeOffsets = range_offsets,
        .Glyphs = glyphs,
    };
}

fn validateSegments(data: []const u8, glyph_domain: u32) FontError!void {
    var reader = Reader.initialize(data);
    const layout = try segmentLayout(&reader);
    if (try readU16At(&reader, layout.StartCodes - @sizeOf(u16)) != 0) return FontError.InvalidCharacterMap;
    if (data.len % @sizeOf(u16) != 0) return FontError.InvalidCharacterMap;

    var previous_end: ?u16 = null;
    for (0..layout.Count) |segment| {
        const offset = segment * @sizeOf(u16);
        const end = try readU16At(&reader, layout.EndCodes + offset);
        const start = try readU16At(&reader, layout.StartCodes + offset);
        if (start > end or (previous_end != null and start <= previous_end.?) or
            (segment + 1 == layout.Count and start != constants.BMP_LAST)) return FontError.InvalidCharacterMap;
        previous_end = end;

        const delta = try readU16At(&reader, layout.Deltas + offset);
        const range_position = layout.RangeOffsets + offset;
        const range = try readU16At(&reader, range_position);
        if (range == 0) {
            for (@as(usize, start)..@as(usize, end) + 1) |character| {
                const code: u16 = @intCast(character);
                if (code +% delta >= glyph_domain) return FontError.GlyphOutOfRange;
            }
            continue;
        }

        const first = range_position + @as(usize, range);
        if (first < layout.Glyphs or first % @sizeOf(u16) != 0) return FontError.InvalidCharacterMap;
        const count = @as(usize, end) - start + 1;
        if (first > data.len or count > (data.len - first) / @sizeOf(u16)) return FontError.UnexpectedEnd;
        try reader.seek(first);
        for (0..count) |_| {
            const glyph = try reader.readU16();
            if (glyph != constants.MISSING_GLYPH and glyph +% delta >= glyph_domain) return FontError.GlyphOutOfRange;
        }
    }
    if (previous_end != constants.BMP_LAST) return FontError.InvalidCharacterMap;
}

fn validateGroups(data: []const u8, glyph_domain: u32) FontError!void {
    var reader = Reader.initialize(data);
    const group_count = try readGroupCount(&reader);
    var previous_end: ?u32 = null;
    for (0..group_count) |_| {
        const start = try reader.readU32();
        const end = try reader.readU32();
        const glyph = try reader.readU32();
        if (start > end or end > constants.UNICODE_LAST or (previous_end != null and start <= previous_end.?)) {
            return FontError.InvalidCharacterMap;
        }
        if (@as(u64, glyph) + (end - start) >= glyph_domain) return FontError.GlyphOutOfRange;
        previous_end = end;
    }
}

fn lookupValidated(data: []const u8, format: u16, codepoint: u32) FontError!u16 {
    return switch (format) {
        constants.FORMAT_SEGMENT_MAPPING => lookupSegments(data, codepoint),
        constants.FORMAT_SEGMENTED_COVERAGE => lookupGroups(data, codepoint),
        else => FontError.UnsupportedCharacterMap,
    };
}

fn lookupSegments(data: []const u8, codepoint: u32) FontError!u16 {
    if (codepoint > constants.BMP_LAST) return constants.MISSING_GLYPH;
    const character: u16 = @intCast(codepoint);
    var reader = Reader.initialize(data);
    const layout = try segmentLayout(&reader);
    var low: usize = 0;
    var high = layout.Count;
    while (low < high) {
        const middle = low + (high - low) / 2;
        const offset = middle * @sizeOf(u16);
        const end = try readU16At(&reader, layout.EndCodes + offset);
        const start = try readU16At(&reader, layout.StartCodes + offset);
        if (character > end) {
            low = middle + 1;
        } else if (character < start) {
            high = middle;
        } else {
            const delta = try readU16At(&reader, layout.Deltas + offset);
            const range_position = layout.RangeOffsets + offset;
            const range = try readU16At(&reader, range_position);
            if (range == 0) return character +% delta;
            const position = range_position + @as(usize, range) + @as(usize, character - start) * @sizeOf(u16);
            if (position < layout.Glyphs or position % @sizeOf(u16) != 0) return FontError.InvalidCharacterMap;
            const glyph = try readU16At(&reader, position);
            return if (glyph == constants.MISSING_GLYPH) constants.MISSING_GLYPH else glyph +% delta;
        }
    }
    return constants.MISSING_GLYPH;
}

fn lookupGroups(data: []const u8, codepoint: u32) FontError!u16 {
    var reader = Reader.initialize(data);
    const group_count = try readGroupCount(&reader);
    var low: usize = 0;
    var high = group_count;
    while (low < high) {
        const middle = low + (high - low) / 2;
        try reader.seek(constants.COVERAGE_HEADER_SIZE + middle * constants.GROUP_SIZE);
        const start = try reader.readU32();
        const end = try reader.readU32();
        const glyph = try reader.readU32();
        if (codepoint < start) {
            high = middle;
        } else if (codepoint > end) {
            low = middle + 1;
        } else {
            const result = @as(u64, glyph) + (codepoint - start);
            if (result >= constants.GLYPH_DOMAIN_SIZE) return FontError.GlyphOutOfRange;
            return @intCast(result);
        }
    }
    return constants.MISSING_GLYPH;
}

fn readGroupCount(reader: *Reader) FontError!usize {
    try reader.seek(constants.COVERAGE_GROUP_COUNT_OFFSET);
    const count = try reader.readU32();
    if (count > reader.remaining() / constants.GROUP_SIZE) return FontError.UnexpectedEnd;
    return count;
}

fn readU16At(reader: *Reader, offset: usize) FontError!u16 {
    try reader.seek(offset);
    return reader.readU16();
}
