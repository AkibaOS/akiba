//! Splash Composition

const graphics = @import("shared").graphics;
const splash = @import("shared").splash;

const text = graphics.text;

const constants = splash.constants;
const strings = splash.strings;

const Canvas = splash.types.canvas.Canvas;
const SplashState = splash.types.state.SplashState;

const labels = strings.splash;
const layout = constants.layout;
const palette = constants.palette;

pub fn paint(canvas: *Canvas, state: *const SplashState) void {
    splash.panel.fillBackground(canvas);
    splash.panel.drawBrackets(canvas);
    splash.wordmark.drawGhost(canvas);
    splash.wordmark.drawCore(canvas);
    drawLabel(canvas);
    drawFooter(canvas);
    refresh(canvas, state);
}

pub fn refresh(canvas: *Canvas, state: *const SplashState) void {
    splash.trail.render(canvas, state);
    splash.progress.render(canvas, state);
}

fn drawLabel(canvas: *Canvas) void {
    const spacing = layout.LABEL_SPACING * canvas.Scale;
    const width = text.measureSpacedString(&canvas.Font, labels.WORDMARK_LABEL, canvas.Scale, spacing);

    text.drawSpacedString(
        &canvas.Surface,
        &canvas.Font,
        canvas.CenterX - @divTrunc(width, 2),
        canvas.LabelY,
        labels.WORDMARK_LABEL,
        palette.DIM_CHROME,
        canvas.Scale,
        spacing,
    );
}

fn drawFooter(canvas: *Canvas) void {
    const scale = canvas.FooterScale;
    const right_width = text.measureString(&canvas.Font, labels.FOOTER_RIGHT, scale);

    text.drawString(&canvas.Surface, &canvas.Font, canvas.FooterLeftX, canvas.FooterY, labels.FOOTER_LEFT, palette.FOOTER, scale);
    text.drawString(&canvas.Surface, &canvas.Font, canvas.FooterRightX - right_width, canvas.FooterY, labels.FOOTER_RIGHT, palette.FOOTER, scale);
}
