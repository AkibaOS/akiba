//! Glyph Outline Extraction Regressions

const std = @import("std");

const constants = @import("tests").fast.constants.render;
const encoding = @import("tests").fast.shared.sfnt.fixture;
const fixture = @import("tests").fast.shared.font.fixture;
const font = @import("shared").font;
const types = @import("tests").fast.types.render;

const GlyphBuffer = font.types.outline.contour.GlyphBuffer;
const GlyphFixture = types.GlyphFixture;

pub fn simpleAndEmptyOutlines() !void {
    const data = fixture.minimal();
    const face = try font.face.load(data.Data[0..data.Length]);
    var buffer = GlyphBuffer.initAllocating(std.testing.allocator);
    defer buffer.deinit();
    try font.outline.load(&face, 1, &buffer);
    try std.testing.expectEqual(@as(usize, 4), buffer.Shape.PointCount);
    try std.testing.expectEqual(@as(usize, 1), buffer.Shape.ContourCount);
    try std.testing.expectEqual(@as(usize, 3), buffer.Shape.ContourEnds[0]);
    try expectPoint(&buffer, 0, 0, 0, true);
    try expectPoint(&buffer, 1, 32, 0, true);
    try expectPoint(&buffer, 2, 32, 64, true);
    try expectPoint(&buffer, 3, 0, 64, true);
    try font.outline.load(&face, 0, &buffer);
    try std.testing.expectEqual(@as(usize, 0), buffer.Shape.PointCount);
    try std.testing.expectEqual(@as(usize, 0), buffer.Shape.ContourCount);
}

pub fn repeatedFlagsAndLongLocations() !void {
    const data = fixture.minimal();
    var face = try font.face.load(data.Data[0..data.Length]);
    var glyph = constants.REPEATED_GLYPH;
    face.Glyf = &glyph;
    face.Loca = &constants.REPEATED_LOCA;
    face.GlyphCount = 1;
    face.IndexToLocationFormat = 1;
    var buffer = GlyphBuffer.initAllocating(std.testing.allocator);
    defer buffer.deinit();
    try font.outline.load(&face, 0, &buffer);
    try std.testing.expectEqual(@as(usize, 4), buffer.Shape.PointCount);
    try expectPoint(&buffer, 0, -10, -10, true);
    try expectPoint(&buffer, 1, 10, -10, true);
    try expectPoint(&buffer, 2, 10, 10, true);
    try expectPoint(&buffer, 3, -10, 10, true);
    glyph[16] = 0x08;
    try font.outline.load(&face, 0, &buffer);
    try expectPoint(&buffer, 0, -10, -10, false);
    try expectPoint(&buffer, 3, -10, 10, false);
    glyph[17] = 4;
    try std.testing.expectError(error.InvalidOutline, font.outline.load(&face, 0, &buffer));
    try std.testing.expectEqual(@as(usize, 0), buffer.Shape.PointCount);
}

pub fn translatedAndScaledComponents() !void {
    const data = fixture.minimal();
    var face = try font.face.load(data.Data[0..data.Length]);
    var buffer = GlyphBuffer.initAllocating(std.testing.allocator);
    defer buffer.deinit();
    try font.outline.load(&face, 3, &buffer);
    try expectPoint(&buffer, 0, 32, -16, true);
    try expectPoint(&buffer, 1, 48, -16, true);
    try expectPoint(&buffer, 2, 48, 16, true);
    try expectPoint(&buffer, 3, 32, 16, true);
    var storage: GlyphFixture = undefined;
    fixture.appendGlyph(&storage, &face, &constants.BYTE_COMPONENT);
    try font.outline.load(&face, 4, &buffer);
    try expectPoint(&buffer, 0, -3, 5, true);
    try expectPoint(&buffer, 2, 29, 69, true);
    face = try font.face.load(data.Data[0..data.Length]);
    fixture.appendGlyph(&storage, &face, &constants.AXIS_COMPONENT);
    try font.outline.load(&face, 4, &buffer);
    try expectPoint(&buffer, 0, -4, 6, true);
    try expectPoint(&buffer, 2, 12, 102, true);
}

pub fn nestedMatrixAndMultipleComponents() !void {
    const data = fixture.minimal();
    var face = try font.face.load(data.Data[0..data.Length]);
    var storage: GlyphFixture = undefined;
    fixture.appendGlyph(&storage, &face, &constants.MATRIX_COMPONENT);
    var buffer = GlyphBuffer.initAllocating(std.testing.allocator);
    defer buffer.deinit();
    try font.outline.load(&face, 4, &buffer);
    try std.testing.expectEqual(@as(usize, 4), buffer.Shape.PointCount);
    try expectPoint(&buffer, 0, 20, 30, true);
    try expectPoint(&buffer, 1, 20, 46, true);
    try expectPoint(&buffer, 2, -12, 46, true);
    try expectPoint(&buffer, 3, -12, 30, true);
    face = try font.face.load(data.Data[0..data.Length]);
    fixture.appendGlyph(&storage, &face, &constants.MULTIPLE_COMPONENTS);
    try font.outline.load(&face, 4, &buffer);
    try std.testing.expectEqual(@as(usize, 8), buffer.Shape.PointCount);
    try std.testing.expectEqual(@as(usize, 2), buffer.Shape.ContourCount);
    try std.testing.expectEqual(@as(usize, 3), buffer.Shape.ContourEnds[0]);
    try std.testing.expectEqual(@as(usize, 7), buffer.Shape.ContourEnds[1]);
    try expectPoint(&buffer, 0, 42, 4, true);
    try expectPoint(&buffer, 2, 58, 36, true);
    try expectPoint(&buffer, 4, -5, -6, true);
    try expectPoint(&buffer, 6, 27, 58, true);
}

pub fn componentDepthBoundary() !void {
    const data = fixture.minimal();
    var face = try font.face.load(data.Data[0..data.Length]);
    var storage: GlyphFixture = undefined;
    var buffer = GlyphBuffer.initAllocating(std.testing.allocator);
    defer buffer.deinit();
    fixture.componentChain(&storage, &face, font.constants.limits.MAX_COMPONENT_DEPTH);
    try font.outline.load(&face, 0, &buffer);
    try std.testing.expectEqual(@as(usize, 4), buffer.Shape.PointCount);
    try expectPoint(&buffer, 2, 32, 64, true);
    fixture.componentChain(&storage, &face, font.constants.limits.MAX_COMPONENT_DEPTH + 1);
    try std.testing.expectError(error.ComponentDepthExceeded, font.outline.load(&face, 0, &buffer));
}

pub fn malformedOutlineBoundsAndLimits() !void {
    const data = fixture.minimal();
    var face = try font.face.load(data.Data[0..data.Length]);
    var buffer = GlyphBuffer.initAllocating(std.testing.allocator);
    defer buffer.deinit();
    try std.testing.expectError(error.GlyphOutOfRange, font.outline.load(&face, face.GlyphCount, &buffer));
    face.GlyphCount = 1;
    face.Glyf = &constants.RECTANGLE_GLYPH;
    face.Loca = constants.LOCA[2..5];
    try std.testing.expectError(error.UnexpectedEnd, font.outline.load(&face, 0, &buffer));
    face.Loca = constants.LOCA[2..6];
    face.Glyf = constants.RECTANGLE_GLYPH[0..21];
    try std.testing.expectError(error.TableOutOfBounds, font.outline.load(&face, 0, &buffer));
    var storage: GlyphFixture = undefined;
    @memcpy(storage.Data[0..constants.RECTANGLE_GLYPH.len], &constants.RECTANGLE_GLYPH);
    @memset(&storage.Loca, 0);
    encoding.writeU16(&storage.Loca, 2, 10);
    face.Glyf = storage.Data[0..20];
    face.Loca = storage.Loca[0..4];
    try std.testing.expectError(error.UnexpectedEnd, font.outline.load(&face, 0, &buffer));
    encoding.writeU16(&storage.Loca, 2, 11);
    face.Glyf = storage.Data[0..22];
    encoding.writeU16(&storage.Data, 0, 129);
    try std.testing.expectError(error.UnexpectedEnd, font.outline.load(&face, 0, &buffer));
    encoding.writeU16(&storage.Data, 0, 1);
    encoding.writeU16(&storage.Data, 10, 1024);
    @memset(storage.Data[14..22], 0x31);
    try std.testing.expectError(error.UnexpectedEnd, font.outline.load(&face, 0, &buffer));
}

pub fn malformedContourEndpoints() !void {
    const data = fixture.minimal();
    var face = try font.face.load(data.Data[0..data.Length]);
    var glyph: [18]u8 = @splat(0);
    var loca: [4]u8 = @splat(0);
    encoding.writeU16(&loca, 2, 9);
    face.GlyphCount = 1;
    face.Glyf = &glyph;
    face.Loca = &loca;
    face.IndexToLocationFormat = 0;
    encoding.writeU16(&glyph, 0, 2);
    encoding.writeU16(&glyph, 10, 2000);
    encoding.writeU16(&glyph, 12, 0);
    glyph[16] = 0x31;
    var buffer = GlyphBuffer.initAllocating(std.testing.allocator);
    defer buffer.deinit();
    try std.testing.expectError(error.InvalidOutline, font.outline.load(&face, 0, &buffer));
    encoding.writeU16(&glyph, 10, 2);
    try std.testing.expectError(error.InvalidOutline, font.outline.load(&face, 0, &buffer));
    encoding.writeU16(&glyph, 10, 0);
    try std.testing.expectError(error.InvalidOutline, font.outline.load(&face, 0, &buffer));
    encoding.writeU16(&glyph, 0, 1);
    encoding.writeU16(&glyph, 10, std.math.maxInt(u16));
    try std.testing.expectError(error.UnexpectedEnd, font.outline.load(&face, 0, &buffer));
    encoding.writeU16(&glyph, 0, 2);
    encoding.writeU16(&glyph, 10, 0);
    encoding.writeU16(&glyph, 12, 1);
    glyph[17] = 0x31;
    try font.outline.load(&face, 0, &buffer);
    try std.testing.expectEqual(@as(usize, 2), buffer.Shape.PointCount);
    try std.testing.expectEqual(@as(usize, 2), buffer.Shape.ContourCount);
    try std.testing.expectEqualSlices(usize, &.{ 0, 1 }, buffer.Shape.ContourEnds[0..2]);
}

pub fn wideTransformIntermediate() !void {
    const data = fixture.minimal();
    var face = try font.face.load(data.Data[0..data.Length]);
    var storage: GlyphFixture = undefined;
    const outline = [_]u8{
        0,    1,    0,    0,    0,    0,    0,    0,    0,    0,
        0,    4,    0,    0,    0x29, 4,    0x7f, 0xff, 0x7f, 0xff,
        0x7f, 0xff, 0x7f, 0xff, 0x7f, 0xff,
    };
    fixture.appendGlyph(&storage, &face, &outline);
    var buffer = GlyphBuffer.initAllocating(std.testing.allocator);
    defer buffer.deinit();
    try font.outline.load(&face, face.GlyphCount - 1, &buffer);
    try expectPoint(&buffer, 4, 5 * 32767, 0, true);

    const Transform = font.types.transform.Transform;
    var scale = Transform.identity();
    scale.A *= 2;
    scale.D *= 2;
    var nested = Transform.identity();
    for (0..font.constants.limits.MAX_COMPONENT_DEPTH) |_| nested = try Transform.compose(nested, scale);
    const placed = try nested.apply(5 * 32767, 0);
    try std.testing.expectEqual(@as(i32, (5 * 32767) << font.constants.limits.MAX_COMPONENT_DEPTH), placed.X);
    try std.testing.expectError(error.InvalidOutline, nested.apply(std.math.maxInt(i32), 0));
    try std.testing.expectError(error.InvalidOutline, Transform.compose(try Transform.compose(nested, nested), scale));
    var half = Transform.identity();
    half.A = @divExact(half.A, 2);
    half.D = @divExact(half.D, 2);
    try half.setOffset(1, -1, true);
    const fractional = try Transform.compose(Transform.identity(), half);
    const point = try fractional.apply(1, -1);
    try std.testing.expectEqual(@as(i32, 1), point.X);
    try std.testing.expectEqual(@as(i32, -1), point.Y);
}

pub fn maximumSimpleOutline() !void {
    const data = fixture.minimal();
    var face = try font.face.load(data.Data[0..data.Length]);
    var storage: GlyphFixture = undefined;
    @memset(&storage.Data, 0);
    @memset(&storage.Loca, 0);
    const contours: usize = 257;
    const points: usize = @as(usize, std.math.maxInt(u16)) + 1;
    encoding.writeU16(&storage.Data, 0, @intCast(contours));
    for (0..contours) |index| {
        encoding.writeU16(&storage.Data, 10 + index * 2, @intCast((index + 1) * points / contours - 1));
    }
    var length = 10 + contours * 2 + 2;
    var remaining = points;
    while (remaining > 0) {
        const run = @min(remaining, 256);
        storage.Data[length] = 0x39;
        storage.Data[length + 1] = @intCast(run - 1);
        length += 2;
        remaining -= run;
    }
    encoding.writeU16(&storage.Loca, 2, @intCast(length / 2));
    face.GlyphCount = 1;
    face.Glyf = storage.Data[0..length];
    face.Loca = storage.Loca[0..4];
    var buffer = GlyphBuffer.initAllocating(std.testing.allocator);
    defer buffer.deinit();
    try font.outline.load(&face, 0, &buffer);
    try std.testing.expectEqual(points, buffer.Shape.PointCount);
    try std.testing.expectEqual(contours, buffer.Shape.ContourCount);
    try std.testing.expectEqual(points - 1, buffer.Shape.ContourEnds[contours - 1]);
    try expectPoint(&buffer, points - 1, 0, 0, true);
}

pub fn componentPlacementAndInstructions() !void {
    const data = fixture.minimal();
    var face = try font.face.load(data.Data[0..data.Length]);
    var storage: GlyphFixture = undefined;
    var glyph = constants.SCALED_COMPONENT ++ [_]u8{ 0, 2, 0xAA, 0xBB };
    encoding.writeU16(&glyph, 0, 0xFFFE);
    encoding.writeU16(&glyph, 10, 0x090B);
    fixture.appendGlyph(&storage, &face, &glyph);
    const flags_offset = constants.GLYF.len + 10;
    const instruction_offset = constants.GLYF.len + constants.SCALED_COMPONENT.len;
    var buffer = GlyphBuffer.initAllocating(std.testing.allocator);
    defer buffer.deinit();

    try font.outline.load(&face, 4, &buffer);
    try expectPoint(&buffer, 0, 16, -8, true);
    try expectPoint(&buffer, 2, 32, 24, true);
    encoding.writeU16(&storage.Data, instruction_offset, 3);
    try std.testing.expectError(error.UnexpectedEnd, font.outline.load(&face, 4, &buffer));
    try std.testing.expectEqual(@as(usize, 0), buffer.Shape.PointCount);
    encoding.writeU16(&storage.Data, flags_offset, 0x0009);
    try std.testing.expectError(error.UnsupportedComponentPlacement, font.outline.load(&face, 4, &buffer));
    encoding.writeU16(&storage.Data, flags_offset, 0x004B);
    try std.testing.expectError(error.InvalidOutline, font.outline.load(&face, 4, &buffer));
    encoding.writeU16(&storage.Data, flags_offset, 0x180B);
    try std.testing.expectError(error.InvalidOutline, font.outline.load(&face, 4, &buffer));
}

fn expectPoint(buffer: *const GlyphBuffer, index: usize, x: i32, y: i32, on_curve: bool) !void {
    const point = buffer.Shape.Points[index];
    try std.testing.expectEqual(x, point.X);
    try std.testing.expectEqual(y, point.Y);
    try std.testing.expectEqual(on_curve, point.OnCurve);
}
