//! Outline Flattening

const common = @import("common");
const font = @import("shared").font;
const raster = @import("shared").raster;

const Fixed16Dot16 = common.datatypes.fixed.Fixed16Dot16;
const Outline = font.types.outline.Outline;
const Placement = raster.types.placement.Placement;
const RasterError = raster.errors.raster.RasterError;
const Shape = raster.types.shape.Shape;

const limits = raster.constants.limits;

pub fn flatten(
    outline: *const Outline,
    scale: Fixed16Dot16,
    origin_x: i32,
    baseline_y: i32,
    shape: *Shape,
) RasterError!void {
    shape.reset();
    errdefer shape.reset();

    if (outline.ContourCount > outline.ContourEnds.len or outline.PointCount > outline.Points.len) {
        return RasterError.InvalidContour;
    }

    const placement = Placement{ .Scale = scale, .OriginX = origin_x, .BaselineY = baseline_y };

    var contour: u16 = 0;
    while (contour < outline.ContourCount) : (contour += 1) {
        try flattenContour(outline, contour, placement, shape);
    }
}

fn flattenContour(outline: *const Outline, contour: u16, placement: Placement, shape: *Shape) RasterError!void {
    const range = outline.contourRange(contour);
    if (range.End < range.Start or range.End >= outline.PointCount) {
        return RasterError.InvalidContour;
    }

    const count = range.End - range.Start + 1;
    if (count < 2) {
        return;
    }

    const first = outline.Points[range.Start];
    const last = outline.Points[range.End];

    var start_x: i32 = undefined;
    var start_y: i32 = undefined;
    var index: u16 = 0;

    if (first.OnCurve) {
        start_x = try placement.deviceX(first.X);
        start_y = try placement.deviceY(first.Y);
        index = 1;
    } else if (last.OnCurve) {
        start_x = try placement.deviceX(last.X);
        start_y = try placement.deviceY(last.Y);
    } else {
        start_x = midpoint(try placement.deviceX(last.X), try placement.deviceX(first.X));
        start_y = midpoint(try placement.deviceY(last.Y), try placement.deviceY(first.Y));
    }

    var current_x = start_x;
    var current_y = start_y;
    var has_control = false;
    var control_x: i32 = 0;
    var control_y: i32 = 0;

    while (index < count) : (index += 1) {
        const point = outline.Points[range.Start + index];
        const point_x = try placement.deviceX(point.X);
        const point_y = try placement.deviceY(point.Y);

        if (point.OnCurve) {
            if (has_control) {
                try emitQuadratic(shape, current_x, current_y, control_x, control_y, point_x, point_y, 0);
                has_control = false;
            } else {
                try shape.addEdge(current_x, current_y, point_x, point_y);
            }
            current_x = point_x;
            current_y = point_y;
            continue;
        }

        if (has_control) {
            const implied_x = midpoint(control_x, point_x);
            const implied_y = midpoint(control_y, point_y);
            try emitQuadratic(shape, current_x, current_y, control_x, control_y, implied_x, implied_y, 0);
            current_x = implied_x;
            current_y = implied_y;
        }

        control_x = point_x;
        control_y = point_y;
        has_control = true;
    }

    if (has_control) {
        try emitQuadratic(shape, current_x, current_y, control_x, control_y, start_x, start_y, 0);
        return;
    }

    try shape.addEdge(current_x, current_y, start_x, start_y);
}

fn emitQuadratic(
    shape: *Shape,
    x0: i32,
    y0: i32,
    control_x: i32,
    control_y: i32,
    x1: i32,
    y1: i32,
    depth: u8,
) RasterError!void {
    const deviation_x = @as(i64, x0) - 2 * @as(i64, control_x) + x1;
    const deviation_y = @as(i64, y0) - 2 * @as(i64, control_y) + y1;
    const deviation = magnitude(deviation_x) + magnitude(deviation_y);

    if (depth >= limits.MAX_SUBDIVISION_DEPTH or deviation <= limits.FLATNESS_TOLERANCE) {
        try shape.addEdge(x0, y0, x1, y1);
        return;
    }

    const left_x = midpoint(x0, control_x);
    const left_y = midpoint(y0, control_y);
    const right_x = midpoint(control_x, x1);
    const right_y = midpoint(control_y, y1);
    const middle_x = midpoint(left_x, right_x);
    const middle_y = midpoint(left_y, right_y);

    try emitQuadratic(shape, x0, y0, left_x, left_y, middle_x, middle_y, depth + 1);
    try emitQuadratic(shape, middle_x, middle_y, right_x, right_y, x1, y1, depth + 1);
}

fn magnitude(value: i64) i64 {
    return if (value < 0) -value else value;
}

fn midpoint(first: i32, second: i32) i32 {
    return @intCast((@as(i64, first) + second) >> 1);
}
