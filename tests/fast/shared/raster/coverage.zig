//! Analytic Area Coverage Regressions

const std = @import("std");

const fixture = @import("tests").fast.shared.raster.fixture;
const raster = @import("shared").raster;

const Shape = raster.types.shape.Shape;
const Workspace = raster.types.workspace.Workspace;

const limits = raster.constants.limits;

pub fn integerRectangleAndEmptyShape() !void {
    var shape = Shape.initAllocating(std.testing.allocator);
    defer shape.deinit();
    var workspace: Workspace = undefined;
    var capture = fixture.initializeCapture();
    raster.fill.fill(&shape, &workspace, fixture.sink(&capture));
    try std.testing.expectEqual(@as(usize, 0), capture.Count);
    try shape.addEdge(0, 0, 2 * limits.ONE_PIXEL, 0);
    raster.fill.fill(&shape, &workspace, fixture.sink(&capture));
    try std.testing.expectEqual(@as(usize, 0), capture.Count);
    try fixture.rectangle(&shape, 0, 0, 2 * limits.ONE_PIXEL, 2 * limits.ONE_PIXEL, false);
    raster.fill.fill(&shape, &workspace, fixture.sink(&capture));
    try std.testing.expect(!capture.Overflow);
    try std.testing.expectEqual(@as(usize, 2), capture.Count);
    try std.testing.expectEqual(@as(i32, 0), capture.Rows[0].X);
    try std.testing.expectEqual(@as(i32, 0), capture.Rows[0].Y);
    try std.testing.expectEqualSlices(u8, &.{ 255, 255, 0 }, capture.Rows[0].Values[0..capture.Rows[0].Length]);
    try std.testing.expectEqualSlices(u8, &.{ 255, 255, 0 }, capture.Rows[1].Values[0..capture.Rows[1].Length]);
}

pub fn fractionalAndNegativeRectangles() !void {
    var shape = Shape.initAllocating(std.testing.allocator);
    defer shape.deinit();
    try fixture.rectangle(&shape, 16, 16, 112, 112, false);
    var workspace: Workspace = undefined;
    var capture = fixture.initializeCapture();
    raster.fill.fill(&shape, &workspace, fixture.sink(&capture));
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
    raster.fill.fill(&shape, &workspace, fixture.sink(&capture));
    try std.testing.expect(!capture.Overflow);
    try std.testing.expectEqual(@as(usize, 3), capture.Count);
    try std.testing.expectEqual(@as(i32, -1), capture.Rows[0].X);
    try std.testing.expectEqual(@as(i32, -1), capture.Rows[0].Y);
    try std.testing.expectEqualSlices(u8, &.{ 64, 128, 64, 0 }, capture.Rows[0].Values[0..capture.Rows[0].Length]);
    try std.testing.expectEqualSlices(u8, &.{ 128, 255, 128, 0 }, capture.Rows[1].Values[0..capture.Rows[1].Length]);
    try std.testing.expectEqualSlices(u8, &.{ 64, 128, 64, 0 }, capture.Rows[2].Values[0..capture.Rows[2].Length]);
}

pub fn diagonalCoverageAndOrientation() !void {
    var shape = Shape.initAllocating(std.testing.allocator);
    defer shape.deinit();
    try shape.addEdge(0, 0, 64, 0);
    try shape.addEdge(64, 0, 0, 64);
    try shape.addEdge(0, 64, 0, 0);
    var workspace: Workspace = undefined;
    var capture = fixture.initializeCapture();
    raster.fill.fill(&shape, &workspace, fixture.sink(&capture));
    try std.testing.expect(!capture.Overflow);
    try std.testing.expectEqual(@as(usize, 1), capture.Count);
    try std.testing.expectEqualSlices(u8, &.{ 128, 0 }, capture.Rows[0].Values[0..capture.Rows[0].Length]);
    shape.reset();
    try shape.addEdge(0, 0, 0, 64);
    try shape.addEdge(0, 64, 64, 0);
    try shape.addEdge(64, 0, 0, 0);
    capture = fixture.initializeCapture();
    raster.fill.fill(&shape, &workspace, fixture.sink(&capture));
    try std.testing.expectEqual(@as(u8, 128), fixture.valueAt(&capture, 0, 0));
}

pub fn nonzeroWindingAndCancellation() !void {
    var shape = Shape.initAllocating(std.testing.allocator);
    defer shape.deinit();
    try fixture.rectangle(&shape, 0, 0, 256, 256, false);
    try fixture.rectangle(&shape, 64, 64, 192, 192, true);
    var workspace: Workspace = undefined;
    var capture = fixture.initializeCapture();
    raster.fill.fill(&shape, &workspace, fixture.sink(&capture));
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
    raster.fill.fill(&shape, &workspace, fixture.sink(&capture));
    try std.testing.expectEqual(@as(u8, 255), fixture.valueAt(&capture, 1, 1));
    shape.reset();
    try fixture.rectangle(&shape, 0, 0, 128, 128, false);
    try fixture.rectangle(&shape, 0, 0, 128, 128, true);
    capture = fixture.initializeCapture();
    raster.fill.fill(&shape, &workspace, fixture.sink(&capture));
    for (capture.Rows[0..capture.Count]) |*row| {
        for (row.Values[0..row.Length]) |value| try std.testing.expectEqual(@as(u8, 0), value);
    }
}

pub fn wideTiledRows() !void {
    var shape = Shape.initAllocating(std.testing.allocator);
    defer shape.deinit();
    const width: i32 = limits.TILE_COLUMNS * 6 + 3;
    try fixture.rectangle(&shape, 0, 0, width * limits.ONE_PIXEL, limits.ONE_PIXEL, false);
    var workspace: Workspace = undefined;
    var capture = fixture.initializeCapture();
    raster.fill.fill(&shape, &workspace, fixture.sink(&capture));
    try std.testing.expect(!capture.Overflow);
    try std.testing.expectEqual(@as(usize, 7), capture.Count);
    for (0..@as(usize, @intCast(width))) |column| {
        try std.testing.expectEqual(@as(u8, 255), fixture.valueAt(&capture, @intCast(column), 0));
    }
    try std.testing.expectEqual(@as(u8, 0), fixture.valueAt(&capture, width, 0));
}

pub fn slopedTiledCrop() !void {
    var shape = Shape.initAllocating(std.testing.allocator);
    defer shape.deinit();
    const columns: i32 = limits.TILE_COLUMNS;
    const pixel = limits.ONE_PIXEL;
    const height = 2 * pixel;
    try shape.addEdge(0, 0, (3 * columns - 4) * pixel, 0);
    try shape.addEdge((3 * columns - 4) * pixel, 0, (3 * columns - 1) * pixel, height);
    try shape.addEdge((3 * columns - 1) * pixel, height, (columns + 4) * pixel, height);
    try shape.addEdge((columns + 4) * pixel, height, 0, 0);
    try fixture.rectangle(&shape, (columns + 8) * pixel, pixel / 2, (2 * columns + 8) * pixel, 3 * pixel / 2, true);

    var workspace: Workspace = undefined;
    var whole = fixture.initializeCapture();
    raster.fill.fill(&shape, &workspace, fixture.sink(&whole));
    var crop = fixture.initializeCapture();
    var sink = fixture.sink(&crop);
    sink.Clip = .{ .Left = 3, .Right = 3 * columns - 2, .Bottom = 2 };
    raster.fill.fill(&shape, &workspace, sink);
    try std.testing.expect(!whole.Overflow and !crop.Overflow and whole.Count != 0 and crop.Count != 0);
    for (0..2) |row| {
        for (3..@as(usize, @intCast(3 * columns - 2))) |column| {
            try std.testing.expectEqual(fixture.valueAt(&whole, @intCast(column), @intCast(row)), fixture.valueAt(&crop, @intCast(column), @intCast(row)));
        }
    }
}

pub fn longClippedEdges() !void {
    var shape = Shape.initAllocating(std.testing.allocator);
    defer shape.deinit();
    const minimum = std.math.minInt(i32);
    const maximum = std.math.maxInt(i32);
    try fixture.rectangle(&shape, minimum, minimum, maximum, maximum, false);
    try fixture.rectangle(&shape, 64, 0, 128, 64, true);
    var workspace: Workspace = undefined;
    var capture = fixture.initializeCapture();
    var sink = fixture.sink(&capture);
    sink.Clip = .{ .Right = 3, .Bottom = 2 };
    raster.fill.fill(&shape, &workspace, sink);
    try std.testing.expect(!capture.Overflow);
    try std.testing.expectEqual(@as(usize, 2), capture.Count);
    try std.testing.expectEqualSlices(u8, &.{ 255, 0, 255 }, capture.Rows[0].Values[0..capture.Rows[0].Length]);
    try std.testing.expectEqualSlices(u8, &.{ 255, 255, 255 }, capture.Rows[1].Values[0..capture.Rows[1].Length]);

    shape.reset();
    try shape.addEdge(minimum, minimum, maximum, minimum);
    try shape.addEdge(maximum, minimum, maximum, maximum);
    try shape.addEdge(maximum, maximum, minimum, minimum);
    capture = fixture.initializeCapture();
    const row = (maximum >> limits.PIXEL_BITS) - 3;
    sink.Clip = .{ .Left = row - 1, .Top = row, .Right = row + 2, .Bottom = row + 1 };
    raster.fill.fill(&shape, &workspace, sink);
    try std.testing.expect(!capture.Overflow);
    try std.testing.expectEqual(@as(usize, 1), capture.Count);
    try std.testing.expectEqualSlices(u8, &.{ 0, 128, 255 }, capture.Rows[0].Values[0..capture.Rows[0].Length]);

    shape.reset();
    try fixture.rectangle(&shape, -256, -256, -128, -128, false);
    try fixture.rectangle(&shape, 256, 256, 384, 384, false);
    capture = fixture.initializeCapture();
    sink.Clip = .{ .Right = 3, .Bottom = 2 };
    raster.fill.fill(&shape, &workspace, sink);
    try std.testing.expectEqual(@as(usize, 0), capture.Count);
}
