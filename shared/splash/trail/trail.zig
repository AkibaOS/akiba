//! Scrolling Boot Message Trail

const graphics = @import("shared").graphics;
const splash = @import("shared").splash;

const text = graphics.text;

const constants = splash.constants;

const Canvas = splash.types.canvas.Canvas;
const SplashState = splash.types.state.SplashState;

const limits = constants.limits;
const palette = constants.palette;

pub fn render(canvas: *Canvas, state: *const SplashState) void {
    const height = text.lineHeight(&canvas.Font, canvas.Scale);
    const band_top = canvas.TrailY - height;
    const band_height = canvas.TrailStep * @as(i32, @intCast(limits.TRAIL_LINES)) + height * 2;

    splash.panel.fillRegion(canvas, 0, band_top, @intCast(canvas.Surface.Width), band_height);

    var index: usize = 0;
    while (index < limits.TRAIL_LINES) : (index += 1) {
        const message = state.line(index);
        if (message.len == 0) {
            continue;
        }

        const newest = index + 1 == limits.TRAIL_LINES;
        const colour = if (newest and state.hasFailed()) palette.FRINGE_MAGENTA else palette.TRAIL[index];

        const width = text.measureString(&canvas.Font, message, canvas.Scale);
        text.drawString(
            &canvas.Surface,
            &canvas.Font,
            canvas.CenterX - @divTrunc(width, 2),
            canvas.TrailY + canvas.TrailStep * @as(i32, @intCast(index)),
            message,
            colour,
            canvas.Scale,
        );
    }
}
