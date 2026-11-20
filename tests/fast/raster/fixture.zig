//! Raster Regression Capture And Geometry

const font = @import("shared").font;
const raster = @import("shared").raster;
const types = @import("tests").fast.types.render;

const CoverageCapture = types.CoverageCapture;
const Outline = font.types.outline.contour.Outline;
const Point = font.types.outline.contour.Point;
const RowSink = raster.types.sink.RowSink;
const Shape = raster.types.shape.Shape;

pub fn initializeCapture() CoverageCapture {
    return .{ .Rows = undefined, .Count = 0, .Overflow = false };
}

pub fn sink(capture: *CoverageCapture) RowSink {
    return .{
        .Clip = .{ .Left = -0x80000000, .Top = -0x80000000, .Right = 0x80000000, .Bottom = 0x80000000 },
        .Context = capture,
        .WriteRow = writeRow,
    };
}

pub fn valueAt(capture: *const CoverageCapture, x: i32, y: i32) u8 {
    for (capture.Rows[0..capture.Count]) |*row| {
        if (row.Y != y or x < row.X) continue;
        const column: usize = @intCast(x - row.X);
        if (column < row.Length) return row.Values[column];
    }
    return 0;
}

pub fn outline(points: []Point, ends: []usize) Outline {
    if (points.len == 0) return .{};
    ends[0] = points.len - 1;
    return .{ .Points = points, .ContourEnds = ends, .PointCount = points.len, .ContourCount = 1 };
}

pub fn rectangle(shape: *Shape, left: i32, top: i32, right: i32, bottom: i32, reverse: bool) !void {
    if (reverse) {
        try shape.addEdge(left, top, left, bottom);
        try shape.addEdge(left, bottom, right, bottom);
        try shape.addEdge(right, bottom, right, top);
        try shape.addEdge(right, top, left, top);
    } else {
        try shape.addEdge(left, top, right, top);
        try shape.addEdge(right, top, right, bottom);
        try shape.addEdge(right, bottom, left, bottom);
        try shape.addEdge(left, bottom, left, top);
    }
}

fn writeRow(context: *anyopaque, y: i32, x: i32, coverage: []const u8) void {
    const capture: *CoverageCapture = @ptrCast(@alignCast(context));
    if (capture.Count >= capture.Rows.len or coverage.len > capture.Rows[0].Values.len) {
        capture.Overflow = true;
        return;
    }
    const row = &capture.Rows[capture.Count];
    row.X = x;
    row.Y = y;
    row.Length = coverage.len;
    @memcpy(row.Values[0..coverage.len], coverage);
    capture.Count += 1;
}
