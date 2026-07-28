//! Progress Rule Rendering

const graphics = @import("shared").graphics;
const splash = @import("shared").splash;

const draw = graphics.draw;

const constants = splash.constants;

const Canvas = splash.types.canvas.Canvas;
const SplashState = splash.types.state.SplashState;

const layout = constants.layout;
const palette = constants.palette;

pub fn render(canvas: *Canvas, state: *const SplashState) void {
    const thickness = layout.PROGRESS_THICKNESS;
    const marker = layout.PROGRESS_MARKER;

    splash.panel.fillRegion(
        canvas,
        canvas.ProgressX - marker,
        canvas.ProgressY - marker,
        canvas.ProgressWidth + marker * 2,
        thickness + marker * 2,
    );
    draw.fillRect(&canvas.Surface, canvas.ProgressX, canvas.ProgressY, canvas.ProgressWidth, thickness, palette.RULE_TRACK);

    if (state.ProgressTotal == 0) {
        return;
    }

    const step: i32 = @intCast(state.ProgressStep);
    const total: i32 = @intCast(state.ProgressTotal);
    const filled = @divTrunc(canvas.ProgressWidth * step, total);

    draw.fillRect(&canvas.Surface, canvas.ProgressX, canvas.ProgressY, filled, thickness, palette.FRINGE_CYAN);

    draw.fillRect(
        &canvas.Surface,
        canvas.ProgressX + filled - @divTrunc(marker, 2),
        canvas.ProgressY + @divTrunc(thickness - marker, 2),
        marker,
        marker,
        palette.FRINGE_MAGENTA,
    );
}
