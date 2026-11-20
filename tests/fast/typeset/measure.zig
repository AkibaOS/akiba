//! UTF8 Measurement And Cursor Regressions

const std = @import("std");

const constants = @import("tests").fast.constants.render;
const fixture = @import("tests").fast.font.fixture;
const font = @import("shared").font;
const raster = @import("shared").raster;
const strings = @import("tests").fast.strings.render;
const typeset = @import("shared").typeset;

const Cursor = typeset.types.cursor.Cursor;
const TextStyle = typeset.types.style.TextStyle;

const limits = raster.constants.limits;

pub fn unicodeCursorAndTracking() !void {
    const data = fixture.minimal();
    const face = try font.face.load(data.Data[0..data.Length]);
    const style: TextStyle = .{ .PixelSize = 4, .Tracking = 1 };
    try std.testing.expectEqual(@as(i32, 19), try typeset.measure.advanceWidth(&face, style, strings.MULTIBYTE));
    var cursor = try Cursor.initialize(&face, style, strings.MULTIBYTE, -2);
    try expectPlaced(&cursor, 1, -128, 1);
    try expectPlaced(&cursor, 2, 192, 3);
    try expectPlaced(&cursor, 3, 512, 6);
    try expectPlaced(&cursor, 3, 832, 10);
    try std.testing.expectEqual(@as(i32, 1152), cursor.PenX);
    try std.testing.expect((try cursor.next()) == null);
    try std.testing.expect((try cursor.next()) == null);
    try std.testing.expectEqual(@as(i32, 1152), cursor.PenX);
}

pub fn measurementRoundingAndGaps() !void {
    const data = fixture.minimal();
    const face = try font.face.load(data.Data[0..data.Length]);
    try std.testing.expectEqual(@as(i32, 0), try typeset.measure.advanceWidth(&face, .{ .PixelSize = 4, .Tracking = 7 }, strings.EMPTY));
    try std.testing.expectEqual(@as(i32, 4), try typeset.measure.advanceWidth(&face, .{ .PixelSize = 4, .Tracking = 7 }, strings.LETTER));
    try std.testing.expectEqual(@as(i32, 7), try typeset.measure.advanceWidth(&face, .{ .PixelSize = 4, .Tracking = -1 }, strings.PAIR));
    try std.testing.expectEqual(@as(i32, 3), try typeset.measure.advanceWidth(&face, .{ .PixelSize = 3, .Tracking = 0 }, strings.MISSING));
    try std.testing.expectEqual(@as(i32, 3), try typeset.measure.ascent(&face, 4));
    var cursor = try Cursor.initialize(&face, .{ .PixelSize = 3, .Tracking = 0 }, strings.MISSING, 0);
    try expectPlaced(&cursor, 0, 0, 1);
    try expectPlaced(&cursor, 0, 96, 2);
    try std.testing.expectEqual(@as(i32, 192), cursor.PenX);
    try wideCoordinates(&face);
    try wideMetrics(face);
}

pub fn invalidUTF8MakesBoundedProgress() !void {
    const data = fixture.minimal();
    const face = try font.face.load(data.Data[0..data.Length]);
    const style: TextStyle = .{ .PixelSize = 4, .Tracking = 0 };
    var cursor = try Cursor.initialize(&face, style, strings.INVALID_UTF8, 0);
    try expectPlaced(&cursor, 0, 0, 1);
    try expectPlaced(&cursor, 1, 128, 2);
    try expectPlaced(&cursor, 0, 384, 3);
    try expectPlaced(&cursor, 0, 512, 4);
    try std.testing.expect((try cursor.next()) == null);
    try std.testing.expectEqual(@as(i32, 10), try typeset.measure.advanceWidth(&face, style, strings.INVALID_UTF8));
}

pub fn fontErrorsPropagate() !void {
    const data = fixture.minimal();
    var face = try font.face.load(data.Data[0..data.Length]);
    const style: TextStyle = .{ .PixelSize = 4, .Tracking = 0 };
    face.GlyphCount = 1;
    var cursor = try Cursor.initialize(&face, style, strings.LETTER, 0);
    try std.testing.expectError(error.GlyphOutOfRange, cursor.next());
    try std.testing.expectError(error.GlyphOutOfRange, typeset.measure.advanceWidth(&face, style, strings.LETTER));
    face.GlyphCount = 4;
    face.Hmtx = &.{};
    try std.testing.expectError(error.UnexpectedEnd, typeset.measure.advanceWidth(&face, style, strings.LETTER));
    face.Charmap = constants.CMAP_UNSUPPORTED[12..];
    try std.testing.expectError(error.UnsupportedCharacterMap, typeset.measure.advanceWidth(&face, style, strings.LETTER));
}

fn expectPlaced(cursor: *Cursor, glyph_id: u16, pen_x: i32, offset: usize) !void {
    const placed = (try cursor.next()).?;
    try std.testing.expectEqual(glyph_id, placed.GlyphId);
    try std.testing.expectEqual(pen_x, placed.PenX);
    try std.testing.expectEqual(offset, cursor.Offset);
}

fn wideCoordinates(face: *const font.types.face.font.Face) !void {
    const tracking = -@divExact(std.math.minInt(i32), limits.ONE_PIXEL);
    const style: TextStyle = .{ .PixelSize = 4, .Tracking = tracking };
    var cursor = try Cursor.initialize(face, style, strings.LETTER, -tracking);
    try expectPlaced(&cursor, 1, std.math.minInt(i32), 1);
    try std.testing.expectEqual(@as(i32, 4 * limits.ONE_PIXEL), cursor.PenX);
    try std.testing.expectEqual(tracking + 8, try typeset.measure.advanceWidth(face, style, strings.PAIR));

    try std.testing.expectError(error.CoordinateOutOfRange, Cursor.initialize(face, style, strings.LETTER, tracking));
    cursor = try Cursor.initialize(face, style, strings.LETTER, 0);
    try std.testing.expectError(error.CoordinateOutOfRange, cursor.next());
    try std.testing.expectEqual(@as(i32, 0), cursor.PenX);
    try std.testing.expectEqual(@as(usize, 0), cursor.Offset);
    try std.testing.expectError(error.MetricOutOfRange, typeset.measure.advanceWidth(face, .{
        .PixelSize = 4,
        .Tracking = std.math.maxInt(i32),
    }, strings.PAIR));
}

fn wideMetrics(original: font.types.face.font.Face) !void {
    try std.testing.expectError(error.InvalidPixelSize, original.scaleFor(0));
    try std.testing.expectError(error.ScaleOutOfRange, original.scaleFor(std.math.maxInt(i32)));

    var face = original;
    face.UnitsPerEm = 32768;
    face.Ascender = std.math.maxInt(i16);
    face.Descender = std.math.minInt(i16);
    face.LineGap = 0;
    try std.testing.expectEqual(@as(i32, 131068), try typeset.measure.ascent(&face, 131072));
    try std.testing.expectEqual(@as(i32, 262140), try face.lineHeight(131072));
    face.UnitsPerEm = 1;
    try std.testing.expectError(error.MetricOutOfRange, typeset.measure.ascent(&face, std.math.maxInt(i32)));
    face.UnitsPerEm = 0;
    try std.testing.expectError(error.InvalidUnitsPerEm, face.scaleFor(4));
    try std.testing.expectError(error.InvalidUnitsPerEm, face.lineHeight(4));
}
