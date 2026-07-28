//! Scrolling Boot Message Trail

const graphics = @import("shared").graphics;
const splash = @import("shared").splash;

const Canvas = splash.types.canvas.Canvas;
const SplashState = splash.types.state.SplashState;
const TextError = graphics.errors.text.TextError;

const layout = splash.constants.layout;
const limits = splash.constants.limits;
const palette = splash.constants.palette;

pub fn render(canvas: *Canvas, state: *const SplashState) TextError!void {
    const style = Canvas.styleFor(layout.TRAIL_SIZE, 0);
    const band_top = canvas.TrailBaseline - layout.TRAIL_SIZE;
    const band_height = canvas.TrailStep * @as(i32, @intCast(limits.TRAIL_LINES)) + layout.TRAIL_SIZE;

    splash.panel.fillRegion(canvas, 0, band_top, @intCast(canvas.Surface.Width), band_height);

    var index: usize = 0;
    while (index < limits.TRAIL_LINES) : (index += 1) {
        const message = state.line(index);
        if (message.len == 0) {
            continue;
        }

        const newest = index + 1 == limits.TRAIL_LINES;
        const colour = if (newest and state.hasFailed()) palette.FRINGE_MAGENTA else palette.TRAIL[index];

        try graphics.text.drawString(
            canvas.Renderer,
            &canvas.Surface,
            &canvas.Face,
            style,
            try splash.measure.centredOrigin(canvas, style, message),
            canvas.TrailBaseline + canvas.TrailStep * @as(i32, @intCast(index)),
            message,
            colour,
            palette.BACKGROUND,
        );
    }
}
