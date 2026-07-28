//! Exact Area Coverage Fill

const raster = @import("shared").raster;

const RasterError = raster.errors.raster.RasterError;
const RowSink = raster.types.sink.RowSink;
const Shape = raster.types.shape.Shape;
const Workspace = raster.types.workspace.Workspace;

const limits = raster.constants.limits;

pub fn fill(shape: *const Shape, workspace: *Workspace, sink: RowSink) RasterError!void {
    if (shape.isEmpty()) {
        return;
    }

    const left = shape.MinX >> limits.PIXEL_BITS;
    const right = (shape.MaxX + limits.PIXEL_MASK) >> limits.PIXEL_BITS;
    const width: usize = @intCast(right - left + 1);

    if (width > limits.MAX_ROW_WIDTH) {
        return RasterError.ShapeTooWide;
    }

    const top = shape.MinY >> limits.PIXEL_BITS;
    const bottom = (shape.MaxY + limits.PIXEL_MASK) >> limits.PIXEL_BITS;

    var row = top;
    while (row <= bottom) : (row += 1) {
        @memset(workspace.Cover[0 .. width + 2], 0);
        @memset(workspace.Area[0 .. width + 2], 0);

        const row_top = row * limits.ONE_PIXEL;
        const row_bottom = row_top + limits.ONE_PIXEL;
        var touched = false;

        var index: u16 = 0;
        while (index < shape.EdgeCount) : (index += 1) {
            const edge = shape.Edges[index];
            if (edge.Y1 <= row_top or edge.Y0 >= row_bottom) {
                continue;
            }

            const span = edge.Y1 - edge.Y0;
            const enter_y = if (edge.Y0 > row_top) edge.Y0 else row_top;
            const leave_y = if (edge.Y1 < row_bottom) edge.Y1 else row_bottom;
            if (enter_y >= leave_y) {
                continue;
            }

            const run = @as(i64, edge.X1 - edge.X0);
            const enter_x: i32 = edge.X0 + @as(i32, @intCast(@divTrunc(run * (enter_y - edge.Y0), span)));
            const leave_x: i32 = edge.X0 + @as(i32, @intCast(@divTrunc(run * (leave_y - edge.Y0), span)));

            renderSegment(
                workspace,
                left,
                enter_x,
                enter_y - row_top,
                leave_x,
                leave_y - row_top,
                edge.Direction,
            );
            touched = true;
        }

        if (!touched) {
            continue;
        }

        var running: i32 = 0;
        var column: usize = 0;
        while (column < width) : (column += 1) {
            running += workspace.Cover[column] * (limits.ONE_PIXEL * 2);
            const value = running - workspace.Area[column];
            workspace.Coverage[column] = toCoverage(value);
        }

        sink.WriteRow(sink.Context, row, left, workspace.Coverage[0..width]);
    }
}

fn renderSegment(
    workspace: *Workspace,
    origin: i32,
    enter_x: i32,
    enter_y: i32,
    leave_x: i32,
    leave_y: i32,
    direction: i32,
) void {
    const first_cell = enter_x >> limits.PIXEL_BITS;
    const last_cell = leave_x >> limits.PIXEL_BITS;

    if (first_cell == last_cell) {
        const height = leave_y - enter_y;
        const inner_enter = enter_x - (first_cell << limits.PIXEL_BITS);
        const inner_leave = leave_x - (last_cell << limits.PIXEL_BITS);
        addCell(workspace, first_cell - origin, height * direction, height * (inner_enter + inner_leave) * direction);
        return;
    }

    const run = leave_x - enter_x;
    const rise = leave_y - enter_y;
    const step: i32 = if (run > 0) 1 else -1;

    var cell = first_cell;
    var current_x = enter_x;
    var current_y = enter_y;

    while (cell != last_cell) {
        const boundary = if (run > 0)
            (cell + 1) << limits.PIXEL_BITS
        else
            cell << limits.PIXEL_BITS;

        const crossing_y = enter_y + @as(i32, @intCast(@divTrunc(@as(i64, rise) * (boundary - enter_x), run)));
        const height = crossing_y - current_y;
        const base = cell << limits.PIXEL_BITS;

        addCell(
            workspace,
            cell - origin,
            height * direction,
            height * ((current_x - base) + (boundary - base)) * direction,
        );

        current_x = boundary;
        current_y = crossing_y;
        cell += step;
    }

    const height = leave_y - current_y;
    const base = last_cell << limits.PIXEL_BITS;
    addCell(
        workspace,
        last_cell - origin,
        height * direction,
        height * ((current_x - base) + (leave_x - base)) * direction,
    );
}

fn addCell(workspace: *Workspace, column: i32, cover: i32, area: i32) void {
    if (column < 0 or column >= limits.MAX_ROW_WIDTH) {
        return;
    }
    const index: usize = @intCast(column);
    workspace.Cover[index] += cover;
    workspace.Area[index] += area;
}

fn toCoverage(value: i32) u8 {
    const magnitude = if (value < 0) -value else value;
    const scaled = magnitude >> limits.COVERAGE_SHIFT;
    return if (scaled >= limits.COVERAGE_FULL) @intCast(limits.COVERAGE_FULL) else @intCast(scaled);
}
