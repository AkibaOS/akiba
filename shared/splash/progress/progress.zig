//! Progress Bar Rendering

const graphics = @import("shared").graphics;
const splash = @import("shared").splash;

const draw = graphics.draw;

const Canvas = splash.types.canvas.Canvas;
const SplashState = splash.types.state.SplashState;

const layout = splash.constants.layout;
const palette = splash.constants.palette;

pub fn targetWidth(state: *const SplashState) i32 {
    if (state.ProgressTotal == 0) return 0;
    const step: i32 = @min(state.ProgressStep, state.ProgressTotal);
    const width = layout.RULE_WIDTH - layout.RULE_PADDING * 2;
    return @divTrunc(width * step, state.ProgressTotal);
}

pub fn render(canvas: *Canvas, state: *const SplashState) void {
    const filled = targetWidth(state);
    const inner_height = layout.RULE_HEIGHT - layout.RULE_PADDING * 2;
    splash.panel.fillRegion(canvas, canvas.RuleX, canvas.RuleY, layout.RULE_WIDTH, layout.RULE_PADDING);
    splash.panel.fillRegion(canvas, canvas.RuleX, canvas.RuleY + layout.RULE_HEIGHT - layout.RULE_PADDING, layout.RULE_WIDTH, layout.RULE_PADDING);
    splash.panel.fillRegion(canvas, canvas.RuleX, canvas.RuleY + layout.RULE_PADDING, layout.RULE_PADDING, inner_height);
    splash.panel.fillRegion(canvas, canvas.RuleX + layout.RULE_PADDING + filled, canvas.RuleY + layout.RULE_PADDING, layout.RULE_WIDTH - layout.RULE_PADDING - filled, inner_height);
    const border = layout.RULE_BORDER;
    const right = canvas.RuleX + layout.RULE_WIDTH - border;
    const bottom = canvas.RuleY + layout.RULE_HEIGHT - border;
    const color = if (state.hasFailed()) palette.FRINGE_MAGENTA else palette.RULE_BORDER;
    draw.fillRect(&canvas.Surface, canvas.RuleX, canvas.RuleY, layout.RULE_WIDTH, border, color);
    draw.fillRect(&canvas.Surface, canvas.RuleX, bottom, layout.RULE_WIDTH, border, color);
    draw.fillRect(&canvas.Surface, canvas.RuleX, canvas.RuleY, border, layout.RULE_HEIGHT, color);
    draw.fillRect(&canvas.Surface, right, canvas.RuleY, border, layout.RULE_HEIGHT, color);
    draw.fillRect(
        &canvas.Surface,
        canvas.RuleX + layout.RULE_PADDING,
        canvas.RuleY + layout.RULE_PADDING,
        filled,
        inner_height,
        if (state.hasFailed()) palette.FRINGE_MAGENTA else palette.RULE_FILL,
    );
}
