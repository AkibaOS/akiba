//! Font Face Loading Regressions

const std = @import("std");

const constants = @import("tests").constants.render;
const encoding = @import("tests").fast.shared.sfnt.fixture;
const fixture = @import("tests").fast.shared.font.fixture;
const font = @import("shared").font;
const graphics = @import("shared").graphics;

pub fn minimalFaceAndMetrics() !void {
    const data = fixture.minimal();
    const face = try font.face.load(data.Data[0..data.Length]);
    try std.testing.expectEqual(@as(u16, 64), face.UnitsPerEm);
    try std.testing.expectEqual(@as(u16, 4), face.GlyphCount);
    try std.testing.expectEqual(@as(i16, 48), face.Ascender);
    try std.testing.expectEqual(@as(i16, -16), face.Descender);
    try std.testing.expectEqual(@as(i32, 8), face.lineHeight(8));
    const first = try font.metrics.glyphMetrics(&face, 0);
    const second = try font.metrics.glyphMetrics(&face, 1);
    const trailing = try font.metrics.glyphMetrics(&face, 2);
    const last = try font.metrics.glyphMetrics(&face, 3);
    try std.testing.expectEqual(@as(u16, 32), first.AdvanceWidth);
    try std.testing.expectEqual(@as(i16, -2), first.LeftSideBearing);
    try std.testing.expectEqual(@as(u16, 64), second.AdvanceWidth);
    try std.testing.expectEqual(@as(i16, 3), second.LeftSideBearing);
    try std.testing.expectEqual(@as(u16, 64), trailing.AdvanceWidth);
    try std.testing.expectEqual(@as(i16, -4), trailing.LeftSideBearing);
    try std.testing.expectEqual(@as(u16, 64), last.AdvanceWidth);
    try std.testing.expectEqual(@as(i16, 5), last.LeftSideBearing);
}

pub fn metricErrors() !void {
    const data = fixture.minimal();
    var face = try font.face.load(data.Data[0..data.Length]);
    try std.testing.expectError(error.GlyphOutOfRange, font.metrics.glyphMetrics(&face, face.GlyphCount));
    face.Hmtx = face.Hmtx[0 .. face.Hmtx.len - 1];
    try std.testing.expectError(error.UnexpectedEnd, font.metrics.glyphMetrics(&face, 3));
    face.LongMetricCount = 0;
    try std.testing.expectError(error.TableOutOfBounds, font.metrics.advanceWidth(&face, 0));
}

pub fn declaredOutlineLimits() !void {
    var data = fixture.minimal();
    encoding.writeU16(&data.Data, constants.MAX_POINTS_OFFSET, @intCast(font.constants.limits.MAX_POINTS));
    encoding.writeU16(&data.Data, constants.MAX_COMPOSITE_OFFSET, @intCast(font.constants.limits.MAX_POINTS));
    encoding.writeU16(&data.Data, constants.MAX_CONTOURS_OFFSET, @intCast(font.constants.limits.MAX_CONTOURS));
    _ = try font.face.load(data.Data[0..data.Length]);
    encoding.writeU16(&data.Data, constants.MAX_POINTS_OFFSET, @intCast(font.constants.limits.MAX_POINTS + 1));
    try std.testing.expectError(error.OutlineTooComplex, font.face.load(data.Data[0..data.Length]));
    encoding.writeU16(&data.Data, constants.MAX_POINTS_OFFSET, @intCast(font.constants.limits.MAX_POINTS));
    encoding.writeU16(&data.Data, constants.MAX_COMPOSITE_OFFSET, @intCast(font.constants.limits.MAX_POINTS + 1));
    try std.testing.expectError(error.OutlineTooComplex, font.face.load(data.Data[0..data.Length]));
    encoding.writeU16(&data.Data, constants.MAX_COMPOSITE_OFFSET, @intCast(font.constants.limits.MAX_POINTS));
    encoding.writeU16(&data.Data, constants.MAX_CONTOURS_OFFSET, @intCast(font.constants.limits.MAX_CONTOURS + 1));
    try std.testing.expectError(error.OutlineTooComplex, font.face.load(data.Data[0..data.Length]));
}

pub fn requiredTableBounds() !void {
    var data = fixture.minimal();
    encoding.writeU32(&data.Data, 24, 53);
    try std.testing.expectError(error.UnexpectedEnd, font.face.load(data.Data[0..data.Length]));
    data = fixture.minimal();
    encoding.writeU32(&data.Data, 12, constants.GLYF_TAG);
    try std.testing.expectError(error.TableMissing, font.face.load(data.Data[0..data.Length]));
    data = fixture.minimal();
    encoding.writeU32(&data.Data, 40, 31);
    try std.testing.expectError(error.UnexpectedEnd, font.face.load(data.Data[0..data.Length]));
    data = fixture.minimal();
    encoding.writeU32(&data.Data, 56, 35);
    try std.testing.expectError(error.UnexpectedEnd, font.face.load(data.Data[0..data.Length]));
}

pub fn malformedFaceRejectsZeroUnitsPerEm() !void {
    var data = fixture.minimal();
    const valid = try font.face.load(data.Data[0..data.Length]);
    try std.testing.expectEqual(@as(u16, 64), valid.UnitsPerEm);
    try std.testing.expectEqual(@as(u16, 1), try font.charmap.lookup(valid.Charmap, 'A'));
    try std.testing.expectEqual(@as(u16, 64), try font.metrics.advanceWidth(&valid, 1));
    encoding.writeU16(&data.Data, constants.UNITS_OFFSET, 0);
    try std.testing.expectError(error.InvalidUnitsPerEm, font.face.load(data.Data[0..data.Length]));
}

pub fn embeddedFaceIntegration() !void {
    const face = try font.face.load(graphics.assets.font.HIKARI);
    try std.testing.expect(face.UnitsPerEm > 0);
    const latin = try font.charmap.lookup(face.Charmap, 'A');
    const kana = try font.charmap.lookup(face.Charmap, 0x30A2);
    try std.testing.expect(latin != 0 and latin < face.GlyphCount);
    try std.testing.expect(kana != 0 and kana < face.GlyphCount);
    try std.testing.expect((try font.metrics.advanceWidth(&face, latin)) > 0);
    try std.testing.expect((try font.metrics.advanceWidth(&face, kana)) > 0);
    var buffer: font.types.outline.GlyphBuffer = undefined;
    try font.outline.load(&face, latin, &buffer);
    try std.testing.expect(buffer.Shape.ContourCount > 0 and buffer.Shape.PointCount > 0);
    try font.outline.load(&face, kana, &buffer);
    try std.testing.expect(buffer.Shape.ContourCount > 0 and buffer.Shape.PointCount > 0);
}
