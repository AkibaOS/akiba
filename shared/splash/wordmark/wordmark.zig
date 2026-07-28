//! Wordmark Rendering

const graphics = @import("shared").graphics;
const splash = @import("shared").splash;

const Canvas = splash.types.canvas.Canvas;
const Color = graphics.types.color.Color;
const TextError = graphics.errors.text.TextError;

const labels = splash.strings.splash;
const layout = splash.constants.layout;
const palette = splash.constants.palette;

pub fn render(canvas: *Canvas) TextError!void {
    const style = Canvas.styleFor(layout.WORDMARK_SIZE, layout.WORDMARK_TRACKING);
    const origin = try splash.measure.centredOrigin(canvas, style, labels.WORDMARK);

    try paint(canvas, origin - layout.FRINGE_OFFSET, palette.FRINGE_CYAN);
    try paint(canvas, origin + layout.FRINGE_OFFSET, palette.FRINGE_MAGENTA);
    try paint(canvas, origin, palette.WORDMARK_CORE);
}

fn paint(canvas: *Canvas, origin: i32, color: Color) TextError!void {
    try graphics.text.drawString(
        canvas.Renderer,
        &canvas.Surface,
        &canvas.Face,
        Canvas.styleFor(layout.WORDMARK_SIZE, layout.WORDMARK_TRACKING),
        origin,
        canvas.WordmarkBaseline,
        labels.WORDMARK,
        color,
        palette.BACKGROUND,
    );
}
