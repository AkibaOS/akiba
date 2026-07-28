//! Panel Background And Frame

const graphics = @import("shared").graphics;
const splash = @import("shared").splash;

const draw = graphics.draw;

const constants = splash.constants;

const Canvas = splash.types.canvas.Canvas;

const layout = constants.layout;
const palette = constants.palette;

pub fn fillRegion(canvas: *Canvas, x: i32, y: i32, width: i32, height: i32) void {
    draw.fillRect(&canvas.Surface, x, y, width, height, palette.BACKGROUND);

    var row = y;
    while (row < y + height) : (row += 1) {
        if (@mod(row, layout.SCANLINE_SPACING) == 0) {
            draw.fillRect(&canvas.Surface, x, row, width, 1, palette.PANEL_SCANLINE);
        }
    }
}

pub fn fillBackground(canvas: *Canvas) void {
    fillRegion(canvas, 0, 0, @intCast(canvas.Surface.Width), @intCast(canvas.Surface.Height));
}

pub fn drawBrackets(canvas: *Canvas) void {
    const thickness = layout.BRACKET_THICKNESS;
    const arm = canvas.BracketArm;

    drawCorner(canvas, canvas.BracketLeft, canvas.BracketTop, arm, arm, thickness);
    drawCorner(canvas, canvas.BracketRight, canvas.BracketTop, -arm, arm, thickness);
    drawCorner(canvas, canvas.BracketLeft, canvas.BracketBottom, arm, -arm, thickness);
    drawCorner(canvas, canvas.BracketRight, canvas.BracketBottom, -arm, -arm, thickness);
}

fn drawCorner(canvas: *Canvas, x: i32, y: i32, horizontal: i32, vertical: i32, thickness: i32) void {
    const left = if (horizontal < 0) x + horizontal else x;
    const top = if (vertical < 0) y + vertical else y;
    const span_x = if (horizontal < 0) -horizontal else horizontal;
    const span_y = if (vertical < 0) -vertical else vertical;

    draw.fillRect(&canvas.Surface, left, y, span_x, thickness, palette.FRAME_BRACKET);
    draw.fillRect(&canvas.Surface, x, top, thickness, span_y, palette.FRAME_BRACKET);
}
