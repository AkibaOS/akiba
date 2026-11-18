//! Clipped Signed-Winding Coverage Sweep

const std = @import("std");

const raster = @import("shared").raster;

const Edge = raster.types.edge.Edge;
const RowSink = raster.types.sink.RowSink;
const Shape = raster.types.shape.Shape;
const Workspace = raster.types.workspace.Workspace;

const limits = raster.constants.limits;

pub fn fill(shape: *Shape, workspace: *Workspace, sink: RowSink) void {
    if (shape.isEmpty()) return;

    const left = @max(sink.Clip.Left, @as(i64, shape.MinX) >> limits.PIXEL_BITS);
    const right = @min(sink.Clip.Right, ceilPixel(shape.MaxX) + 1);
    const top = @max(sink.Clip.Top, @as(i64, shape.MinY) >> limits.PIXEL_BITS);
    const bottom = @min(sink.Clip.Bottom, ceilPixel(shape.MaxY));
    if (left >= right or top >= bottom) return;

    const edges = shape.Edges[0..shape.EdgeCount];
    std.mem.sortUnstable(Edge, edges, {}, startsBefore);
    var next: usize = 0;
    var active = edges.len;
    var row = top;
    while (row < bottom) {
        const row_top = row * limits.ONE_PIXEL;
        const row_bottom = row_top + limits.ONE_PIXEL;
        var link = &active;
        while (link.* < edges.len) {
            const edge = &edges[link.*];
            if (edge.Y1 <= row_top) link.* = edge.SweepNext else link = &edge.SweepNext;
        }
        while (next < edges.len and edges[next].Y0 < row_bottom) : (next += 1) {
            if (edges[next].Y1 <= row_top) continue;
            edges[next].SweepNext = active;
            active = next;
        }
        if (active == edges.len) {
            if (next == edges.len) break;
            row = @as(i64, edges[next].Y0) >> limits.PIXEL_BITS;
            continue;
        }

        var tile = left;
        while (tile < right) {
            const width: usize = @intCast(@min(right - tile, @as(i64, limits.TILE_COLUMNS)));
            fillTile(edges, active, workspace, sink, row, tile, width);
            tile += @intCast(width);
        }
        row += 1;
    }
}

fn startsBefore(_: void, first: Edge, second: Edge) bool {
    return first.Y0 < second.Y0;
}

fn ceilPixel(coordinate: i32) i64 {
    return (@as(i64, coordinate) + limits.PIXEL_MASK) >> limits.PIXEL_BITS;
}

fn fillTile(edges: []const Edge, active: usize, workspace: *Workspace, sink: RowSink, row: i64, origin: i64, width: usize) void {
    @memset(workspace.Cover[0..width], 0);
    @memset(workspace.Area[0..width], 0);

    const row_top = row * limits.ONE_PIXEL;
    const row_bottom = row_top + limits.ONE_PIXEL;
    var prefix: i64 = 0;
    var index = active;
    while (index < edges.len) : (index = edges[index].SweepNext) {
        const edge = &edges[index];
        const enter_y = @max(row_top, edge.Y0);
        const leave_y = @min(row_bottom, edge.Y1);
        if (enter_y >= leave_y) continue;

        const span: u64 = @intCast(@as(i64, edge.Y1) - edge.Y0);
        const run = @as(i64, edge.X1) - edge.X0;
        const enter_x = edge.X0 + interpolate(run, @intCast(enter_y - edge.Y0), span);
        const leave_x = edge.X0 + interpolate(run, @intCast(leave_y - edge.Y0), span);
        prefix += renderSegment(workspace, origin, width, enter_x, enter_y - row_top, leave_x, leave_y - row_top, edge.Direction);
    }

    var running = prefix * (limits.ONE_PIXEL * 2);
    for (0..width) |column| {
        running += workspace.Cover[column] * (limits.ONE_PIXEL * 2);
        workspace.Coverage[column] = toCoverage(running - workspace.Area[column]);
    }
    sink.WriteRow(sink.Context, @intCast(row), @intCast(origin), workspace.Coverage[0..width]);
}

fn renderSegment(workspace: *Workspace, origin: i64, width: usize, enter_x: i64, enter_y: i64, leave_x: i64, leave_y: i64, direction: i32) i64 {
    const tile_left = origin * limits.ONE_PIXEL;
    const tile_right = tile_left + @as(i64, @intCast(width)) * limits.ONE_PIXEL;
    if (enter_x == leave_x) {
        const cover = (leave_y - enter_y) * direction;
        if (enter_x < tile_left) return cover;
        if (enter_x < tile_right) {
            const cell = enter_x >> limits.PIXEL_BITS;
            const inner_x = enter_x - cell * limits.ONE_PIXEL;
            addCell(workspace, @intCast(cell - origin), cover, cover * (inner_x * 2));
        }
        return 0;
    }

    const segment_left = @min(enter_x, leave_x);
    const segment_right = @max(enter_x, leave_x);
    const run = leave_x - enter_x;
    const rise = leave_y - enter_y;
    var prefix: i64 = 0;
    if (segment_left < tile_left) {
        const boundary_y = crossing(enter_x, enter_y, run, rise, @min(tile_left, segment_right));
        prefix = (if (run > 0) boundary_y - enter_y else leave_y - boundary_y) * direction;
    }

    var current_x = @max(segment_left, tile_left);
    const stop = @min(segment_right, tile_right);
    while (current_x < stop) {
        const cell = current_x >> limits.PIXEL_BITS;
        const base = cell * limits.ONE_PIXEL;
        const next_x = @min(stop, base + limits.ONE_PIXEL);
        const current_y = crossing(enter_x, enter_y, run, rise, current_x);
        const next_y = crossing(enter_x, enter_y, run, rise, next_x);
        const height = if (run > 0) next_y - current_y else current_y - next_y;
        const cover = height * direction;
        addCell(workspace, @intCast(cell - origin), cover, cover * ((current_x - base) + (next_x - base)));
        current_x = next_x;
    }
    return prefix;
}

fn crossing(enter_x: i64, enter_y: i64, run: i64, rise: i64, boundary: i64) i64 {
    return enter_y + @as(i64, @intCast((@abs(boundary - enter_x) * @as(u64, @intCast(rise))) / @abs(run)));
}

fn interpolate(run: i64, offset: u64, span: u64) i64 {
    const magnitude: i64 = @intCast((@abs(run) * offset) / span);
    return if (run < 0) -magnitude else magnitude;
}

fn addCell(workspace: *Workspace, column: usize, cover: i64, area: i64) void {
    workspace.Cover[column] += cover;
    workspace.Area[column] += area;
}

fn toCoverage(value: i64) u8 {
    const scaled = @abs(value) >> limits.COVERAGE_SHIFT;
    return @intCast(@min(scaled, @as(u64, limits.COVERAGE_FULL)));
}
