//! Outline Flattening

const common = @import("common");
const font = @import("shared").font;
const raster = @import("shared").raster;

const Fixed16Dot16 = common.datatypes.fixed.Fixed16Dot16;
const Outline = font.types.outline.Outline;
const RasterError = raster.errors.raster.RasterError;
const Shape = raster.types.shape.Shape;

const limits = raster.constants.limits;

const Placement = struct {
    Scale: Fixed16Dot16,
    OriginX: i32,
    BaselineY: i32,

    fn deviceX(self: Placement, units: i32) i32 {
        return self.OriginX + self.Scale.applyToUnits(units).Raw;
    }

    fn deviceY(self: Placement, units: i32) i32 {
        return self.BaselineY - self.Scale.applyToUnits(units).Raw;
    }
};

pub fn flatten(
    outline: *const Outline,
    scale: Fixed16Dot16,
    origin_x: i32,
    baseline_y: i32,
    shape: *Shape,
) RasterError!void {
    shape.reset();

    const placement = Placement{ .Scale = scale, .OriginX = origin_x, .BaselineY = baseline_y };

    var contour: u16 = 0;
    while (contour < outline.ContourCount) : (contour += 1) {
        try flattenContour(outline, contour, placement, shape);
    }
}

fn flattenContour(outline: *const Outline, contour: u16, placement: Placement, shape: *Shape) RasterError!void {
    const range = outline.contourRange(contour);
    if (range.End < range.Start) {
        return;
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
        start_x = placement.deviceX(first.X);
        start_y = placement.deviceY(first.Y);
        index = 1;
    } else if (last.OnCurve) {
        start_x = placement.deviceX(last.X);
        start_y = placement.deviceY(last.Y);
        index = 0;
    } else {
        start_x = placement.deviceX(@divTrunc(first.X + last.X, 2));
        start_y = placement.deviceY(@divTrunc(first.Y + last.Y, 2));
        index = 0;
    }

    var current_x = start_x;
    var current_y = start_y;
    var has_control = false;
    var control_x: i32 = 0;
    var control_y: i32 = 0;

    while (index < count) : (index += 1) {
        const point = outline.Points[range.Start + index];
        const px = placement.deviceX(point.X);
        const py = placement.deviceY(point.Y);

        if (point.OnCurve) {
            if (has_control) {
                try emitQuadratic(shape, current_x, current_y, control_x, control_y, px, py, 0);
                has_control = false;
            } else {
                try shape.addEdge(current_x, current_y, px, py);
            }
            current_x = px;
            current_y = py;
            continue;
        }

        if (has_control) {
            const implied_x = @divTrunc(control_x + px, 2);
            const implied_y = @divTrunc(control_y + py, 2);
            try emitQuadratic(shape, current_x, current_y, control_x, control_y, implied_x, implied_y, 0);
            current_x = implied_x;
            current_y = implied_y;
        }

        control_x = px;
        control_y = py;
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
    const deviation_x = x0 - 2 * control_x + x1;
    const deviation_y = y0 - 2 * control_y + y1;
    const deviation = magnitude(deviation_x) + magnitude(deviation_y);

    if (depth >= limits.MAX_SUBDIVISION_DEPTH or deviation <= limits.FLATNESS_TOLERANCE) {
        try shape.addEdge(x0, y0, x1, y1);
        return;
    }

    const left_x = (x0 + control_x) >> 1;
    const left_y = (y0 + control_y) >> 1;
    const right_x = (control_x + x1) >> 1;
    const right_y = (control_y + y1) >> 1;
    const middle_x = (left_x + right_x) >> 1;
    const middle_y = (left_y + right_y) >> 1;

    try emitQuadratic(shape, x0, y0, left_x, left_y, middle_x, middle_y, depth + 1);
    try emitQuadratic(shape, middle_x, middle_y, right_x, right_y, x1, y1, depth + 1);
}

fn magnitude(value: i32) i32 {
    return if (value < 0) -value else value;
}
