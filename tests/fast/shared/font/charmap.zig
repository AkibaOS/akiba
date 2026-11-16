//! Supported Character Map Regressions

const std = @import("std");

const constants = @import("tests").constants.render;
const encoding = @import("tests").fast.shared.sfnt.fixture;
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
