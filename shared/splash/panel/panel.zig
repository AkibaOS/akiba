//! Panel Background And Frame

const graphics = @import("shared").graphics;
const splash = @import("shared").splash;

const draw = graphics.draw;

const integer = @import("utils").math.integer;

const Canvas = splash.types.canvas.Canvas;
const Color = graphics.types.color.Color;

const layout = splash.constants.layout;
const palette = splash.constants.palette;

pub fn fillRegion(canvas: *Canvas, x: i32, y: i32, width: i32, height: i32) void {
    const surface_width: i32 = @intCast(canvas.Surface.Width);
    const surface_height: i32 = @intCast(canvas.Surface.Height);

    const left = if (x < 0) 0 else x;
    const top = if (y < 0) 0 else y;
    const right = if (x + width > surface_width) surface_width else x + width;
    const bottom = if (y + height > surface_height) surface_height else y + height;

    var row = top;
    while (row < bottom) : (row += 1) {
        const base = if (@mod(row, layout.SCANLINE_PERIOD) == 0)
            palette.PANEL_SCANLINE
        else
            palette.BACKGROUND;

        var column = left;
        while (column < right) : (column += 1) {
            draw.putPixel(&canvas.Surface, column, row, shade(canvas, base, column, row));
        }
    }
}

pub fn fillBackground(canvas: *Canvas) void {
    fillRegion(canvas, 0, 0, @intCast(canvas.Surface.Width), @intCast(canvas.Surface.Height));
}

fn shade(canvas: *Canvas, base: Color, x: i32, y: i32) Color {
    const width: i32 = @intCast(canvas.Surface.Width);
    const height: i32 = @intCast(canvas.Surface.Height);

    const radius_x = @divTrunc(width * layout.VIGNETTE_RADIUS, layout.PER_MILLE);
    const radius_y = @divTrunc(height * layout.VIGNETTE_RADIUS, layout.PER_MILLE);
    if (radius_x == 0 or radius_y == 0) {
        return base;
    }

    const offset_x = x - @divTrunc(width * layout.VIGNETTE_CENTRE_X, layout.PER_MILLE);
    const offset_y = y - @divTrunc(height * layout.VIGNETTE_CENTRE_Y, layout.PER_MILLE);

    const normal_x = @divTrunc(@as(i64, offset_x) * layout.VIGNETTE_EDGE, radius_x);
    const normal_y = @divTrunc(@as(i64, offset_y) * layout.VIGNETTE_EDGE, radius_y);
    const squared: u64 = @intCast(normal_x * normal_x + normal_y * normal_y);

    const distance: i32 = @intCast(integer.squareRoot(squared));
    if (distance <= layout.VIGNETTE_START) {
        return base;
    }

    const span = layout.VIGNETTE_EDGE - layout.VIGNETTE_START;
    const travelled = if (distance - layout.VIGNETTE_START > span) span else distance - layout.VIGNETTE_START;
    const strength = @divTrunc(layout.VIGNETTE_STRENGTH * travelled, span);

    return base.blend(palette.VOID, @intCast(strength), 255);
}

pub fn drawBrackets(canvas: *Canvas) void {
    const arm = layout.BRACKET_ARM;
    const thickness = layout.BRACKET_THICKNESS;

    drawCorner(canvas, canvas.BracketLeft, canvas.BracketTop, arm, arm, thickness);
    drawCorner(canvas, canvas.BracketRight, canvas.BracketTop, -arm, arm, thickness);
    drawCorner(canvas, canvas.BracketLeft, canvas.BracketBottom, arm, -arm, thickness);
    drawCorner(canvas, canvas.BracketRight, canvas.BracketBottom, -arm, -arm, thickness);
}

fn drawCorner(canvas: *Canvas, x: i32, y: i32, horizontal: i32, vertical: i32, thickness: i32) void {
    const reach_x = if (horizontal < 0) -horizontal else horizontal;
    const reach_y = if (vertical < 0) -vertical else vertical;

    const arm_left = if (horizontal < 0) x + horizontal + 1 else x;
    const arm_top = if (vertical < 0) y + vertical + 1 else y;
    const stroke_left = if (horizontal < 0) x - thickness + 1 else x;
    const stroke_top = if (vertical < 0) y - thickness + 1 else y;

    draw.fillRect(&canvas.Surface, arm_left, stroke_top, reach_x, thickness, palette.FRAME_BRACKET);
    draw.fillRect(&canvas.Surface, stroke_left, arm_top, thickness, reach_y, palette.FRAME_BRACKET);
}
