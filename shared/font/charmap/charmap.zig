//! Character To Glyph Mapping

const font = @import("shared").font;
const sfnt = @import("shared").sfnt;

const constants = font.constants.charmap;

const FontError = font.errors.font.FontError;
const Reader = sfnt.types.reader.Reader;

const ENCODING_RECORD_SIZE: usize = 8;

pub fn select(table: []const u8) FontError![]const u8 {
    var reader = Reader.initialize(table);
    _ = try reader.readU16();
    const record_count = try reader.readU16();

    var best: ?[]const u8 = null;
    var best_rank: u8 = 0;

    var index: u16 = 0;
    while (index < record_count) : (index += 1) {
        try reader.seek(4 + @as(usize, index) * ENCODING_RECORD_SIZE);
        const platform = try reader.readU16();
        const encoding = try reader.readU16();
        const offset = try reader.readU32();

        if (offset >= table.len) {
            continue;
        }
        const subtable = table[offset..];

        var format_reader = Reader.initialize(subtable);
        const format = try format_reader.readU16();

        const rank = rankSubtable(platform, encoding, format);
        if (rank > best_rank) {
            best_rank = rank;
            best = subtable;
        }
    }

    return best orelse FontError.UnsupportedCharacterMap;
}

fn rankSubtable(platform: u16, encoding: u16, format: u16) u8 {
    if (format == constants.FORMAT_SEGMENTED_COVERAGE) {
        if (platform == constants.PLATFORM_WINDOWS and encoding == constants.ENCODING_WINDOWS_FULL) {
            return 4;
        }
        if (platform == constants.PLATFORM_UNICODE) {
            return 3;
        }
    }
    if (format == constants.FORMAT_SEGMENT_MAPPING) {
        if (platform == constants.PLATFORM_WINDOWS and encoding == constants.ENCODING_WINDOWS_BMP) {
            return 2;
        }
        if (platform == constants.PLATFORM_UNICODE) {
            return 1;
        }
    }
    return 0;
}

pub fn lookup(subtable: []const u8, codepoint: u32) FontError!u16 {
    var reader = Reader.initialize(subtable);
    const format = try reader.readU16();

    return switch (format) {
        constants.FORMAT_SEGMENT_MAPPING => lookupSegmentMapping(subtable, codepoint),
        constants.FORMAT_SEGMENTED_COVERAGE => lookupSegmentedCoverage(subtable, codepoint),
        else => FontError.UnsupportedCharacterMap,
    };
}

fn lookupSegmentMapping(subtable: []const u8, codepoint: u32) FontError!u16 {
    if (codepoint > 0xFFFF) {
        return constants.MISSING_GLYPH;
    }
    const character: u16 = @truncate(codepoint);

    var reader = Reader.initialize(subtable);
    try reader.seek(6);
    const segment_count_doubled = try reader.readU16();
    const segment_count = segment_count_doubled / 2;

    const end_codes: usize = 14;
    const start_codes: usize = end_codes + segment_count_doubled + 2;
    const deltas: usize = start_codes + segment_count_doubled;
    const range_offsets: usize = deltas + segment_count_doubled;

    var segment: u16 = 0;
    while (segment < segment_count) : (segment += 1) {
        try reader.seek(end_codes + @as(usize, segment) * 2);
        const end_code = try reader.readU16();
        if (character > end_code) {
            continue;
        }

        try reader.seek(start_codes + @as(usize, segment) * 2);
        const start_code = try reader.readU16();
        if (character < start_code) {
            return constants.MISSING_GLYPH;
        }

        try reader.seek(deltas + @as(usize, segment) * 2);
        const delta = try reader.readU16();

        const range_offset_position = range_offsets + @as(usize, segment) * 2;
        try reader.seek(range_offset_position);
        const range_offset = try reader.readU16();

        if (range_offset == 0) {
            return character +% delta;
        }

        const glyph_position = range_offset_position + @as(usize, range_offset) +
            @as(usize, character - start_code) * 2;
        try reader.seek(glyph_position);
        const glyph = try reader.readU16();

        if (glyph == constants.MISSING_GLYPH) {
            return constants.MISSING_GLYPH;
        }
        return glyph +% delta;
    }

    return constants.MISSING_GLYPH;
}

fn lookupSegmentedCoverage(subtable: []const u8, codepoint: u32) FontError!u16 {
    var reader = Reader.initialize(subtable);
    try reader.seek(12);
    const group_count = try reader.readU32();

    const groups: usize = 16;
    const GROUP_SIZE: usize = 12;

    var low: u32 = 0;
    var high: u32 = group_count;

    while (low < high) {
        const middle = low + (high - low) / 2;
        try reader.seek(groups + @as(usize, middle) * GROUP_SIZE);
        const start_character = try reader.readU32();
        const end_character = try reader.readU32();
        const start_glyph = try reader.readU32();

        if (codepoint < start_character) {
            high = middle;
        } else if (codepoint > end_character) {
            low = middle + 1;
        } else {
            return @truncate(start_glyph + (codepoint - start_character));
        }
    }

    return constants.MISSING_GLYPH;
}
