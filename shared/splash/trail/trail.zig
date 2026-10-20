//! Boot Status Rows

const graphics = @import("shared").graphics;
const splash = @import("shared").splash;

const Canvas = splash.types.canvas.Canvas;
const SplashState = splash.types.state.SplashState;
const Surface = graphics.types.surface.Surface;
const TextError = graphics.errors.text.TextError;

const labels = splash.strings.splash;
const layout = splash.constants.layout;
const limits = splash.constants.limits;
const palette = splash.constants.palette;

var pixels: [limits.TRAIL_BUFFER_PIXELS]u32 = undefined;

pub fn render(canvas: *Canvas, state: *const SplashState) TextError!void {
    const band_top = canvas.TrailBaseline - layout.TRAIL_SIZE;
    const width: i32 = @intCast(limits.TRAIL_BUFFER_WIDTH);
    const height: i32 = @intCast(limits.TRAIL_BUFFER_HEIGHT);
    const left = @max(0, -canvas.RuleX);
    const top = @max(0, -band_top);
    const right = @min(width, @as(i32, @intCast(canvas.Surface.Width)) - canvas.RuleX);
    const bottom = @min(height, @as(i32, @intCast(canvas.Surface.Height)) - band_top);
    if (left >= right or top >= bottom) return;

    @memset(&pixels, palette.BACKGROUND.toPixel(canvas.Surface.Format));
    var buffered = canvas.*;
    buffered.Surface = Surface.initialize(@intFromPtr(&pixels), @intCast(width), @intCast(height), @intCast(width), canvas.Surface.Format);
    buffered.RuleX = 0;
    buffered.TrailBaseline = layout.TRAIL_SIZE;
    buffered.BackgroundOffsetX += canvas.RuleX;
    buffered.BackgroundOffsetY += band_top;
    splash.panel.fillRegion(&buffered, left, top, right - left, bottom - top);
    try paintRows(&buffered, state);

    var row = top;
    while (row < bottom) : (row += 1) {
        const source = @as(usize, @intCast(row)) * limits.TRAIL_BUFFER_WIDTH + @as(usize, @intCast(left));
        const destination = canvas.Surface.offset(@intCast(canvas.RuleX + left), @intCast(band_top + row));
        const count: usize = @intCast(right - left);
        @memcpy(canvas.Surface.Base[destination..][0..count], pixels[source..][0..count]);
    }
}

fn paintRows(canvas: *Canvas, state: *const SplashState) TextError!void {
    const style = Canvas.styleFor(layout.TRAIL_SIZE, layout.TRAIL_TRACKING);
    const marker_x = canvas.RuleX + layout.TRAIL_INSET;
    const left = marker_x + layout.ACTIVE_COLUMN_WIDTH;
    const activity = labels.STATUS_ACTIVITY[0 .. canvas.ActivityFrame % labels.STATUS_ACTIVITY.len + 1];

    var index: usize = 0;
    while (index < limits.TRAIL_LINES) : (index += 1) {
        const message = state.line(index);
        if (message.len == 0) continue;
        const newest = index + 1 == limits.TRAIL_LINES;
        const failed = state.hasFailed() and index + limits.FAILED_TRAIL_LINES >= limits.TRAIL_LINES;
        const active = newest and !failed and state.ProgressStep < state.ProgressTotal;
        const baseline = canvas.TrailBaseline + canvas.TrailStep * @as(i32, @intCast(index));
        const color = if (failed) palette.FRINGE_MAGENTA else if (newest) palette.TRAIL_CURRENT else palette.TRAIL_COMPLETE;
        const status_width = if (failed) try splash.measure.width(canvas, style, labels.STATUS_FAILED) else layout.STATUS_WIDTH;
        const status_x = canvas.RuleX + layout.RULE_WIDTH - status_width;
        var label_surface = canvas.Surface;
        label_surface.Width = @min(label_surface.Width, @as(u32, @intCast(@max(0, status_x - layout.STATUS_GAP))));
        try graphics.text.drawString(canvas.Renderer, &label_surface, &canvas.Face, style, left, baseline, message, color, null);
        if (active) drawActive(canvas, marker_x, baseline - layout.ACTIVE_HEIGHT);
        try graphics.text.drawString(
            canvas.Renderer,
            &canvas.Surface,
            &canvas.Face,
            style,
            status_x,
            baseline,
            if (active) activity else if (failed) labels.STATUS_FAILED else labels.STATUS_COMPLETE,
            color,
            null,
        );
    }
}

fn drawActive(canvas: *Canvas, x: i32, y: i32) void {
    const middle = @divTrunc(layout.ACTIVE_HEIGHT, 2);
    var row: i32 = 0;
    while (row < layout.ACTIVE_HEIGHT) : (row += 1) {
        const reach = if (row <= middle) row else layout.ACTIVE_HEIGHT - row;
        const width = @max(1, @divTrunc(layout.ACTIVE_WIDTH * reach, middle));
        graphics.draw.fillRect(&canvas.Surface, x, y + row, width, 1, palette.TRAIL_CURRENT);
    }
}
