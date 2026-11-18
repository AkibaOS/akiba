//! Supported Character Map Regressions

const std = @import("std");

const constants = @import("tests").constants.render;
const encoding = @import("tests").fast.shared.sfnt.fixture;
const fixture = @import("tests").fast.shared.font.fixture;
const font = @import("shared").font;

pub fn segmentedMapping() !void {
    try std.testing.expectEqual(@as(u16, 1), try font.charmap.lookup(&constants.CMAP4, 'A'));
    try std.testing.expectEqual(@as(u16, 3), try font.charmap.lookup(&constants.CMAP4, 'a'));
    try std.testing.expectEqual(@as(u16, 0), try font.charmap.lookup(&constants.CMAP4, 'b'));
    try std.testing.expectEqual(@as(u16, 5), try font.charmap.lookup(&constants.CMAP4, 'c'));
    try std.testing.expectEqual(@as(u16, 0), try font.charmap.lookup(&constants.CMAP4, '@'));
    try std.testing.expectEqual(@as(u16, 0), try font.charmap.lookup(&constants.CMAP4, 'B'));
    try std.testing.expectEqual(@as(u16, 0), try font.charmap.lookup(&constants.CMAP4, 'd'));
    try std.testing.expectEqual(@as(u16, 0), try font.charmap.lookup(&constants.CMAP4, 0xFFFF));
    try std.testing.expectEqual(@as(u16, 0), try font.charmap.lookup(&constants.CMAP4, 0x1F642));
    try std.testing.expectError(error.UnexpectedEnd, font.charmap.lookup(constants.CMAP4[0..39], 'c'));
}

pub fn segmentedCoverage() !void {
    try std.testing.expectEqual(@as(u16, 1), try font.charmap.lookup(&constants.CMAP12, 'A'));
    try std.testing.expectEqual(@as(u16, 2), try font.charmap.lookup(&constants.CMAP12, 'B'));
    try std.testing.expectEqual(@as(u16, 3), try font.charmap.lookup(&constants.CMAP12, 0x1F642));
    try std.testing.expectEqual(@as(u16, 0), try font.charmap.lookup(&constants.CMAP12, 0x1F641));
    try std.testing.expectEqual(@as(u16, 0), try font.charmap.lookup(&constants.CMAP12, 0x1F643));
    try std.testing.expectEqual(@as(u16, 0), try font.charmap.lookup(&constants.CMAP12, 'C'));
    try std.testing.expectEqual(@as(u16, 0), try font.charmap.lookup(&constants.CMAP12, 0));
    try std.testing.expectError(error.UnexpectedEnd, font.charmap.lookup(constants.CMAP12[0..16], 'A'));
}

pub fn declaredLengths() !void {
    var segments = constants.CMAP4;
    encoding.writeU16(&segments, 2, 16);
    try std.testing.expectError(error.UnexpectedEnd, font.charmap.lookup(&segments, 'A'));
    var groups = constants.CMAP12;
    encoding.writeU32(&groups, 4, 16);
    try std.testing.expectError(error.UnexpectedEnd, font.charmap.lookup(&groups, 'A'));
    const selected = try font.charmap.select(&(constants.CMAP ++ constants.ENDIAN_BYTES));
    try std.testing.expectEqual(constants.CMAP12.len, selected.len);
}

pub fn glyphDomain() !void {
    var groups = constants.CMAP12;
    const latin_start_glyph = 36;
    encoding.writeU32(&groups, latin_start_glyph, 65536);
    try std.testing.expectError(error.GlyphOutOfRange, font.charmap.lookup(&groups, 'A'));
    encoding.writeU32(&groups, latin_start_glyph, std.math.maxInt(u32));
    try std.testing.expectError(error.GlyphOutOfRange, font.charmap.lookup(&groups, 'B'));
    const data = fixture.minimal();
    var face = try font.face.load(data.Data[0..data.Length]);
    encoding.writeU32(&groups, latin_start_glyph, face.GlyphCount);
    face.Charmap = &groups;
    try std.testing.expectError(error.GlyphOutOfRange, font.charmap.lookupFace(&face, 'A'));
}

pub fn selectionPreferenceAndErrors() !void {
    var choices = constants.CMAP_CHOICES;
    const selected = try font.charmap.select(&choices);
    try std.testing.expectEqual(@intFromPtr(&choices[234]), @intFromPtr(selected.ptr));
    try std.testing.expectEqual(@as(u16, 3), try font.charmap.lookup(selected, 0x1F642));
    encoding.writeU16(&choices, 12, 3);
    encoding.writeU16(&choices, 14, 10);
    encoding.writeU16(&choices, 20, 0);
    encoding.writeU16(&choices, 22, 4);
    const retained = try font.charmap.select(&choices);
    try std.testing.expectEqual(@intFromPtr(&choices[74]), @intFromPtr(retained.ptr));
    try std.testing.expectError(error.UnsupportedCharacterMap, font.charmap.select(&constants.CMAP_UNSUPPORTED));
    var invalid = constants.CMAP_UNSUPPORTED;
    encoding.writeU32(&invalid, 8, std.math.maxInt(u32));
    try std.testing.expectError(error.UnsupportedCharacterMap, font.charmap.select(&invalid));
    encoding.writeU32(&invalid, 8, @intCast(invalid.len - 1));
    try std.testing.expectError(error.UnexpectedEnd, font.charmap.select(&invalid));
    try std.testing.expectError(error.UnexpectedEnd, font.charmap.select(constants.CMAP[0..11]));
    try std.testing.expectError(error.UnsupportedCharacterMap, font.charmap.lookup(constants.CMAP_UNSUPPORTED[12..], 'A'));
}
