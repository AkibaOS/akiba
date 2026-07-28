//! Progress Rule Rendering

const graphics = @import("shared").graphics;
const splash = @import("shared").splash;

const draw = graphics.draw;

const Canvas = splash.types.canvas.Canvas;
const SplashState = splash.types.state.SplashState;

const layout = splash.constants.layout;
const palette = splash.constants.palette;

pub fn render(canvas: *Canvas, state: *const SplashState) void {
    splash.panel.fillRegion(
        canvas,
        canvas.RuleX - layout.MARKER_WIDTH,
        canvas.RuleY - layout.MARKER_RISE,
        layout.RULE_WIDTH + layout.MARKER_WIDTH * 2,
        layout.MARKER_HEIGHT + layout.MARKER_RISE,
    );

    draw.fillRect(
        &canvas.Surface,
        canvas.RuleX,
        canvas.RuleY,
        layout.RULE_WIDTH,
        layout.RULE_THICKNESS,
        palette.RULE_TRACK,
    );

    if (state.ProgressTotal == 0) {
        return;
    }

    const step: i32 = @intCast(state.ProgressStep);
    const total: i32 = @intCast(state.ProgressTotal);
    const filled = @divTrunc(layout.RULE_WIDTH * step, total);

    draw.fillRect(&canvas.Surface, canvas.RuleX, canvas.RuleY, filled, layout.RULE_THICKNESS, palette.FRINGE_CYAN);

    draw.fillRect(
        &canvas.Surface,
        canvas.RuleX + filled - @divTrunc(layout.MARKER_WIDTH, 2),
        canvas.RuleY - layout.MARKER_RISE,
        layout.MARKER_WIDTH,
        layout.MARKER_HEIGHT,
        palette.FRINGE_MAGENTA,
    );
}
