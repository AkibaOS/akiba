//! Analytic Area Coverage Regressions

const std = @import("std");

const fixture = @import("tests").fast.shared.raster.fixture;
const raster = @import("shared").raster;

const Shape = raster.types.shape.Shape;
const Workspace = raster.types.workspace.Workspace;

const limits = raster.constants.limits;

pub fn integerRectangleAndEmptyShape() !void {
    var shape: Shape = undefined;
    shape.reset();
    var workspace: Workspace = undefined;
    var capture = fixture.initializeCapture();
    try raster.fill.fill(&shape, &workspace, fixture.sink(&capture));
    try std.testing.expectEqual(@as(usize, 0), capture.Count);
    try shape.addEdge(0, 0, 2 * limits.ONE_PIXEL, 0);
    try raster.fill.fill(&shape, &workspace, fixture.sink(&capture));
    try std.testing.expectEqual(@as(usize, 0), capture.Count);
    try fixture.rectangle(&shape, 0, 0, 2 * limits.ONE_PIXEL, 2 * limits.ONE_PIXEL, false);
    try raster.fill.fill(&shape, &workspace, fixture.sink(&capture));
    try std.testing.expect(!capture.Overflow);
    try std.testing.expectEqual(@as(usize, 2), capture.Count);
    try std.testing.expectEqual(@as(i32, 0), capture.Rows[0].X);
    try std.testing.expectEqual(@as(i32, 0), capture.Rows[0].Y);
    try std.testing.expectEqualSlices(u8, &.{ 255, 255, 0 }, capture.Rows[0].Values[0..capture.Rows[0].Length]);
    try std.testing.expectEqualSlices(u8, &.{ 255, 255, 0 }, capture.Rows[1].Values[0..capture.Rows[1].Length]);
}

pub fn fractionalAndNegativeRectangles() !void {
    var shape: Shape = undefined;
    shape.reset();
    try fixture.rectangle(&shape, 16, 16, 112, 112, false);
    var workspace: Workspace = undefined;
    var capture = fixture.initializeCapture();
    try raster.fill.fill(&shape, &workspace, fixture.sink(&capture));
    try std.testing.expect(!capture.Overflow);
    try std.testing.expectEqual(@as(usize, 2), capture.Count);
    try std.testing.expectEqual(@as(u8, 144), fixture.valueAt(&capture, 0, 0));
    try std.testing.expectEqual(@as(u8, 144), fixture.valueAt(&capture, 1, 0));
    try std.testing.expectEqual(@as(u8, 144), fixture.valueAt(&capture, 0, 1));
    try std.testing.expectEqual(@as(u8, 144), fixture.valueAt(&capture, 1, 1));
    try std.testing.expectEqual(@as(u8, 0), fixture.valueAt(&capture, 2, 0));
    shape.reset();
    try fixture.rectangle(&shape, -32, -32, 96, 96, false);
    capture = fixture.initializeCapture();
    try raster.fill.fill(&shape, &workspace, fixture.sink(&capture));
    try std.testing.expect(!capture.Overflow);
    try std.testing.expectEqual(@as(usize, 3), capture.Count);
    try std.testing.expectEqual(@as(i32, -1), capture.Rows[0].X);
    try std.testing.expectEqual(@as(i32, -1), capture.Rows[0].Y);
    try std.testing.expectEqualSlices(u8, &.{ 64, 128, 64, 0 }, capture.Rows[0].Values[0..capture.Rows[0].Length]);
    try std.testing.expectEqualSlices(u8, &.{ 128, 255, 128, 0 }, capture.Rows[1].Values[0..capture.Rows[1].Length]);
    try std.testing.expectEqualSlices(u8, &.{ 64, 128, 64, 0 }, capture.Rows[2].Values[0..capture.Rows[2].Length]);
}

pub fn diagonalCoverageAndOrientation() !void {
    var shape: Shape = undefined;
    shape.reset();
    try shape.addEdge(0, 0, 64, 0);
    try shape.addEdge(64, 0, 0, 64);
    try shape.addEdge(0, 64, 0, 0);
    var workspace: Workspace = undefined;
    var capture = fixture.initializeCapture();
    try raster.fill.fill(&shape, &workspace, fixture.sink(&capture));
    try std.testing.expect(!capture.Overflow);
    try std.testing.expectEqual(@as(usize, 1), capture.Count);
    try std.testing.expectEqualSlices(u8, &.{ 128, 0 }, capture.Rows[0].Values[0..capture.Rows[0].Length]);
    shape.reset();
    try shape.addEdge(0, 0, 0, 64);
    try shape.addEdge(0, 64, 64, 0);
    try shape.addEdge(64, 0, 0, 0);
    capture = fixture.initializeCapture();
    try raster.fill.fill(&shape, &workspace, fixture.sink(&capture));
    try std.testing.expectEqual(@as(u8, 128), fixture.valueAt(&capture, 0, 0));
}

pub fn nonzeroWindingAndCancellation() !void {
    var shape: Shape = undefined;
    shape.reset();
    try fixture.rectangle(&shape, 0, 0, 256, 256, false);
    try fixture.rectangle(&shape, 64, 64, 192, 192, true);
    var workspace: Workspace = undefined;
    var capture = fixture.initializeCapture();
    try raster.fill.fill(&shape, &workspace, fixture.sink(&capture));
    try std.testing.expect(!capture.Overflow);
    for (0..4) |row| {
        for (0..4) |column| {
            const hole = row > 0 and row < 3 and column > 0 and column < 3;
            try std.testing.expectEqual(@as(u8, if (hole) 0 else 255), fixture.valueAt(&capture, @intCast(column), @intCast(row)));
        }
    }
    shape.reset();
    try fixture.rectangle(&shape, 0, 0, 256, 256, false);
    try fixture.rectangle(&shape, 64, 64, 192, 192, false);
    capture = fixture.initializeCapture();
    try raster.fill.fill(&shape, &workspace, fixture.sink(&capture));
    try std.testing.expectEqual(@as(u8, 255), fixture.valueAt(&capture, 1, 1));
    shape.reset();
    try fixture.rectangle(&shape, 0, 0, 128, 128, false);
    try fixture.rectangle(&shape, 0, 0, 128, 128, true);
    capture = fixture.initializeCapture();
    try raster.fill.fill(&shape, &workspace, fixture.sink(&capture));
    for (capture.Rows[0..capture.Count]) |*row| {
        for (row.Values[0..row.Length]) |value| try std.testing.expectEqual(@as(u8, 0), value);
    }
}

pub fn rowWidthBoundary() !void {
    var shape: Shape = undefined;
    shape.reset();
    const maximum: i32 = @intCast(limits.MAX_ROW_WIDTH);
    try fixture.rectangle(&shape, 0, 0, (maximum - 1) * limits.ONE_PIXEL, limits.ONE_PIXEL, false);
    var workspace: Workspace = undefined;
    var capture = fixture.initializeCapture();
    try raster.fill.fill(&shape, &workspace, fixture.sink(&capture));
    try std.testing.expect(!capture.Overflow);
    try std.testing.expectEqual(@as(usize, 1), capture.Count);
    try std.testing.expectEqual(limits.MAX_ROW_WIDTH, capture.Rows[0].Length);
    try std.testing.expectEqual(@as(u8, 255), capture.Rows[0].Values[limits.MAX_ROW_WIDTH - 2]);
    try std.testing.expectEqual(@as(u8, 0), capture.Rows[0].Values[limits.MAX_ROW_WIDTH - 1]);
    shape.reset();
    try fixture.rectangle(&shape, 0, 0, maximum * limits.ONE_PIXEL, limits.ONE_PIXEL, false);
    capture = fixture.initializeCapture();
    try std.testing.expectError(error.ShapeTooWide, raster.fill.fill(&shape, &workspace, fixture.sink(&capture)));
    try std.testing.expectEqual(@as(usize, 0), capture.Count);
    shape.reset();
    try fixture.rectangle(&shape, std.math.minInt(i32), 0, std.math.maxInt(i32), limits.ONE_PIXEL, false);
    try std.testing.expectError(error.ShapeTooWide, raster.fill.fill(&shape, &workspace, fixture.sink(&capture)));
    try std.testing.expectEqual(@as(usize, 0), capture.Count);
    shape.reset();
    try fixture.rectangle(&shape, std.math.maxInt(i32) - 127, std.math.maxInt(i32) - 127, std.math.maxInt(i32), std.math.maxInt(i32), false);
    try raster.fill.fill(&shape, &workspace, fixture.sink(&capture));
    try std.testing.expect(!capture.Overflow);
    try std.testing.expectEqual(@as(usize, 2), capture.Count);
    try std.testing.expectEqual(@as(i32, 33554430), capture.Rows[0].X);
    try std.testing.expectEqual(@as(i32, 33554430), capture.Rows[0].Y);
    try std.testing.expectEqual(@as(usize, 3), capture.Rows[0].Length);
}
