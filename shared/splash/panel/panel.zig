//! Panel Background And Frame

const graphics = @import("shared").graphics;
const splash = @import("shared").splash;

const draw = graphics.draw;

const Canvas = splash.types.canvas.Canvas;
const Color = graphics.types.color.Color;

const background = splash.constants.background;
const layout = splash.constants.layout;
const palette = splash.constants.palette;

pub fn fillRegion(canvas: *Canvas, x: i32, y: i32, width: i32, height: i32) void {
    const surface_width: i32 = @intCast(canvas.Surface.Width);
    const surface_height: i32 = @intCast(canvas.Surface.Height);
    const left = @max(x, 0);
    const top = @max(y, 0);
    const right = @min(x + width, surface_width);
    const bottom = @min(y + height, surface_height);

    var row = top;
    while (row < bottom) : (row += 1) {
        const source_y: usize = @intCast(@divTrunc((@as(i64, row) + canvas.BackgroundOffsetY) * background.HEIGHT, canvas.BackgroundHeight));
        const source_row = source_y * @as(usize, background.WIDTH) * background.CHANNELS;
        var column = left;
        while (column < right) : (column += 1) {
            const source_x: usize = @intCast(@divTrunc((@as(i64, column) + canvas.BackgroundOffsetX) * background.WIDTH, canvas.BackgroundWidth));
            const offset = source_row + source_x * background.CHANNELS;
            const color = Color.rgb(background.PIXELS[offset], background.PIXELS[offset + 1], background.PIXELS[offset + 2]);
            draw.putPixel(&canvas.Surface, column, row, color);
        }
    }
}

pub fn fillBackground(canvas: *Canvas) void {
    fillRegion(canvas, 0, 0, @intCast(canvas.Surface.Width), @intCast(canvas.Surface.Height));
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
