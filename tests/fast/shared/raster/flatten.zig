//! Outline Placement And Implied Point Regressions

const std = @import("std");

const common = @import("common");
const constants = @import("tests").constants.render;
const fixture = @import("tests").fast.shared.raster.fixture;
const raster = @import("shared").raster;

const Fixed16Dot16 = common.datatypes.fixed.Fixed16Dot16;
const Shape = raster.types.shape.Shape;
const Workspace = raster.types.workspace.Workspace;

pub fn placementAndReset() !void {
    var outline = fixture.outline(&constants.RECTANGLE_POINTS);
    var shape: Shape = undefined;
    try raster.flatten.flatten(&outline, Fixed16Dot16.fromRatio(1, 2), -32, 192, &shape);
    try std.testing.expectEqual(@as(u16, 2), shape.EdgeCount);
    try std.testing.expectEqual(@as(i32, -32), shape.MinX);
    try std.testing.expectEqual(@as(i32, 96), shape.MaxX);
    try std.testing.expectEqual(@as(i32, 64), shape.MinY);
    try std.testing.expectEqual(@as(i32, 192), shape.MaxY);
    var workspace: Workspace = undefined;
    var capture = fixture.initializeCapture();
    try raster.fill.fill(&shape, &workspace, fixture.sink(&capture));
    try std.testing.expect(!capture.Overflow);
    try std.testing.expectEqual(@as(u8, 128), fixture.valueAt(&capture, -1, 1));
    try std.testing.expectEqual(@as(u8, 255), fixture.valueAt(&capture, 0, 1));
    try std.testing.expectEqual(@as(u8, 128), fixture.valueAt(&capture, 1, 2));
    outline.reset();
    try raster.flatten.flatten(&outline, Fixed16Dot16.fromRatio(1, 1), 0, 0, &shape);
    try std.testing.expect(shape.isEmpty());
}

pub fn impliedPointsAndClosure() !void {
    const implied = fixture.outline(&constants.IMPLIED_POINTS);
    const explicit = fixture.outline(&constants.EXPLICIT_POINTS);
    var implicit_shape: Shape = undefined;
    var explicit_shape: Shape = undefined;
    const scale = Fixed16Dot16.fromRatio(1, 1);
    try raster.flatten.flatten(&implied, scale, 0, 256, &implicit_shape);
    try raster.flatten.flatten(&explicit, scale, 0, 256, &explicit_shape);
    try std.testing.expect(implicit_shape.EdgeCount > 4);
    try std.testing.expectEqual(explicit_shape.EdgeCount, implicit_shape.EdgeCount);
    for (implicit_shape.Edges[0..implicit_shape.EdgeCount], explicit_shape.Edges[0..explicit_shape.EdgeCount]) |actual, expected| {
        try std.testing.expectEqualDeep(expected, actual);
    }
    var rotated = explicit;
    @memcpy(rotated.Points[0..7], constants.EXPLICIT_POINTS[1..]);
    rotated.Points[7] = constants.EXPLICIT_POINTS[0];
    try raster.flatten.flatten(&rotated, scale, 0, 256, &explicit_shape);
    var workspace: Workspace = undefined;
    var first = fixture.initializeCapture();
    var second = fixture.initializeCapture();
    try raster.fill.fill(&implicit_shape, &workspace, fixture.sink(&first));
    try raster.fill.fill(&explicit_shape, &workspace, fixture.sink(&second));
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
}

pub fn translatedCurves() !void {
    const outline = fixture.outline(&constants.IMPLIED_POINTS);
    const scale = Fixed16Dot16.fromRatio(1, 1);
    var reference: Shape = undefined;
    var translated: Shape = undefined;
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

pub fn edgeCapacity() !void {
    var shape: Shape = undefined;
    shape.reset();
    for (0..raster.constants.limits.MAX_EDGES) |_| try shape.addEdge(0, 0, 64, 64);
    try std.testing.expectEqual(@as(u16, @intCast(raster.constants.limits.MAX_EDGES)), shape.EdgeCount);
    try std.testing.expectError(error.TooManyEdges, shape.addEdge(64, 64, 0, 0));
    try std.testing.expectEqual(@as(u16, @intCast(raster.constants.limits.MAX_EDGES)), shape.EdgeCount);
}
