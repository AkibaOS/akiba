//! Outline Placement And Implied Point Regressions

const std = @import("std");

const common = @import("common");
const constants = @import("tests").fast.constants.render;
const fixture = @import("tests").fast.shared.raster.fixture;
const font = @import("shared").font;
const raster = @import("shared").raster;

const Fixed16Dot16 = common.datatypes.fixed.Fixed16Dot16;
const Placement = raster.types.placement.Placement;
const Point = font.types.outline.contour.Point;
const Shape = raster.types.shape.Shape;
const Workspace = raster.types.workspace.Workspace;

const limits = raster.constants.limits;

pub fn placementAndReset() !void {
    var points = constants.RECTANGLE_POINTS;
    var ends: [1]usize = undefined;
    var outline = fixture.outline(&points, &ends);
    var shape = Shape.initAllocating(std.testing.allocator);
    defer shape.deinit();
    try raster.flatten.flatten(&outline, try Fixed16Dot16.fromRatio(1, 2), -32, 192, &shape);
    try std.testing.expectEqual(@as(usize, 2), shape.EdgeCount);
    try std.testing.expectEqual(@as(i32, -32), shape.MinX);
    try std.testing.expectEqual(@as(i32, 96), shape.MaxX);
    try std.testing.expectEqual(@as(i32, 64), shape.MinY);
    try std.testing.expectEqual(@as(i32, 192), shape.MaxY);
    var workspace: Workspace = undefined;
    var capture = fixture.initializeCapture();
    raster.fill.fill(&shape, &workspace, fixture.sink(&capture));
    try std.testing.expect(!capture.Overflow);
    try std.testing.expectEqual(@as(u8, 128), fixture.valueAt(&capture, -1, 1));
    try std.testing.expectEqual(@as(u8, 255), fixture.valueAt(&capture, 0, 1));
    try std.testing.expectEqual(@as(u8, 128), fixture.valueAt(&capture, 1, 2));
    const identity = try Fixed16Dot16.fromRatio(1, 1);
    try std.testing.expectError(error.CoordinateOutOfRange, raster.flatten.flatten(&outline, identity, std.math.maxInt(i32), 0, &shape));
    try std.testing.expect(shape.isEmpty());
    outline.ContourEnds[0] = outline.PointCount;
    try std.testing.expectError(error.InvalidContour, raster.flatten.flatten(&outline, identity, 0, 0, &shape));
    outline.reset();
    try raster.flatten.flatten(&outline, identity, 0, 0, &shape);
    try std.testing.expect(shape.isEmpty());
    try widePlacement(identity);
}

pub fn impliedPointsAndClosure() !void {
    var implied_points = constants.IMPLIED_POINTS;
    var explicit_points = constants.EXPLICIT_POINTS;
    var implied_ends: [1]usize = undefined;
    var explicit_ends: [1]usize = undefined;
    const implied = fixture.outline(&implied_points, &implied_ends);
    const explicit = fixture.outline(&explicit_points, &explicit_ends);
    var implicit_shape = Shape.initAllocating(std.testing.allocator);
    defer implicit_shape.deinit();
    var explicit_shape = Shape.initAllocating(std.testing.allocator);
    defer explicit_shape.deinit();
    const scale = try Fixed16Dot16.fromRatio(1, 1);
    try raster.flatten.flatten(&implied, scale, 0, 256, &implicit_shape);
    try raster.flatten.flatten(&explicit, scale, 0, 256, &explicit_shape);
    try std.testing.expect(implicit_shape.EdgeCount > 4);
    try std.testing.expectEqual(explicit_shape.EdgeCount, implicit_shape.EdgeCount);
    for (implicit_shape.Edges[0..implicit_shape.EdgeCount], explicit_shape.Edges[0..explicit_shape.EdgeCount]) |actual, expected| {
        try std.testing.expectEqualDeep(expected, actual);
    }
    var rotated_points = constants.EXPLICIT_POINTS;
    @memcpy(rotated_points[0..7], constants.EXPLICIT_POINTS[1..]);
    rotated_points[7] = constants.EXPLICIT_POINTS[0];
    var rotated_ends: [1]usize = undefined;
    const rotated = fixture.outline(&rotated_points, &rotated_ends);
    try raster.flatten.flatten(&rotated, scale, 0, 256, &explicit_shape);
    var workspace: Workspace = undefined;
    var first = fixture.initializeCapture();
    var second = fixture.initializeCapture();
    raster.fill.fill(&implicit_shape, &workspace, fixture.sink(&first));
    raster.fill.fill(&explicit_shape, &workspace, fixture.sink(&second));
    try std.testing.expect(!first.Overflow and !second.Overflow);
    try std.testing.expectEqual(@as(u8, 255), fixture.valueAt(&first, 1, 1));
    for (0..5) |row| {
        for (0..5) |column| {
            try std.testing.expectEqual(
                fixture.valueAt(&first, @intCast(column), @intCast(row)),
                fixture.valueAt(&second, @intCast(column), @intCast(row)),
            );
        }
    }
    try fractionalImpliedMidpoint(&implicit_shape, &explicit_shape);
}

pub fn translatedCurves() !void {
    var points = constants.IMPLIED_POINTS;
    var ends: [1]usize = undefined;
    const outline = fixture.outline(&points, &ends);
    const scale = try Fixed16Dot16.fromRatio(1, 1);
    var reference = Shape.initAllocating(std.testing.allocator);
    defer reference.deinit();
    var translated = Shape.initAllocating(std.testing.allocator);
    defer translated.deinit();
    try raster.flatten.flatten(&outline, scale, 0, 256, &reference);
    try raster.flatten.flatten(&outline, scale, constants.RASTER_HIGH_ORIGIN, 256, &translated);
    try std.testing.expectEqual(reference.EdgeCount, translated.EdgeCount);
    for (reference.Edges[0..reference.EdgeCount], translated.Edges[0..translated.EdgeCount]) |first, second| {
        try std.testing.expectEqual(first.X0 + constants.RASTER_HIGH_ORIGIN, second.X0);
        try std.testing.expectEqual(first.X1 + constants.RASTER_HIGH_ORIGIN, second.X1);
        try std.testing.expectEqual(first.Y0, second.Y0);
        try std.testing.expectEqual(first.Y1, second.Y1);
    }
}

pub fn edgeGrowthAndFixedScratch() !void {
    var cells: [1]raster.types.edge.Edge = undefined;
    var fixed = Shape.initFixed(&cells);
    try fixed.addEdge(0, 0, 64, 64);
    try std.testing.expectError(error.ScratchExhausted, fixed.addEdge(64, 64, 0, 0));
    try std.testing.expectEqual(@as(usize, 1), fixed.EdgeCount);

    const contour_count = 2500;
    const points = try std.testing.allocator.alloc(Point, contour_count * constants.RECTANGLE_POINTS.len);
    defer std.testing.allocator.free(points);
    const ends = try std.testing.allocator.alloc(usize, contour_count);
    defer std.testing.allocator.free(ends);
    for (ends, 0..) |*end, contour| {
        const start = contour * constants.RECTANGLE_POINTS.len;
        @memcpy(points[start..][0..constants.RECTANGLE_POINTS.len], &constants.RECTANGLE_POINTS);
        end.* = start + constants.RECTANGLE_POINTS.len - 1;
    }
    const outline: font.types.outline.contour.Outline = .{ .Points = points, .ContourEnds = ends, .PointCount = points.len, .ContourCount = ends.len };
    var shape = Shape.initAllocating(std.testing.allocator);
    defer shape.deinit();
    try raster.flatten.flatten(&outline, try Fixed16Dot16.fromRatio(1, 1), 0, 256, &shape);
    try std.testing.expectEqual(@as(usize, contour_count * 2), shape.EdgeCount);
    var capture = fixture.initializeCapture();
    var workspace: Workspace = undefined;
    raster.fill.fill(&shape, &workspace, fixture.sink(&capture));
    try std.testing.expectEqual(@as(u8, 255), fixture.valueAt(&capture, 2, 2));
    try std.testing.expectEqual(@as(u8, 0), fixture.valueAt(&capture, 4, 2));
}

fn widePlacement(identity: Fixed16Dot16) !void {
    const units = -@divExact(std.math.minInt(i32), limits.ONE_PIXEL);
    const placed: Placement = .{ .Scale = identity, .OriginX = std.math.minInt(i32), .BaselineY = std.math.maxInt(i32) };
    try std.testing.expectEqual(@as(i32, 0), try placed.deviceX(units));
    try std.testing.expectEqual(@as(i32, -1), try placed.deviceY(units));
    try std.testing.expectError(error.CoordinateOutOfRange, placed.deviceX(-1));
    try std.testing.expectError(error.CoordinateOutOfRange, placed.deviceY(-1));
}

fn fractionalImpliedMidpoint(wrapped: *Shape, internal: *Shape) !void {
    var points = [_]Point{
        .{ .X = -1, .Y = 0, .OnCurve = false },
        .{ .X = 1, .Y = 4, .OnCurve = true },
        .{ .X = 2, .Y = 1, .OnCurve = false },
    };
    var rotated_points = [_]Point{ points[1], points[2], points[0] };
    var ends: [1]usize = undefined;
    var rotated_ends: [1]usize = undefined;
    const outline = fixture.outline(&points, &ends);
    const rotated = fixture.outline(&rotated_points, &rotated_ends);
    const scale = try Fixed16Dot16.fromRatio(1, 32);
    try raster.flatten.flatten(&outline, scale, 0, 0, wrapped);
    try raster.flatten.flatten(&rotated, scale, 0, 0, internal);
    try std.testing.expectEqual(@as(usize, 2), wrapped.EdgeCount);
    try std.testing.expectEqual(wrapped.EdgeCount, internal.EdgeCount);
    try std.testing.expectEqualDeep(wrapped.Edges[0], internal.Edges[1]);
    try std.testing.expectEqualDeep(wrapped.Edges[1], internal.Edges[0]);
}
