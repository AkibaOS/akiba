//! Splash Composition

const graphics = @import("shared").graphics;
const splash = @import("shared").splash;

const Canvas = splash.types.canvas.Canvas;
const SplashState = splash.types.state.SplashState;
const TextError = graphics.errors.text.TextError;

const labels = splash.strings.splash;
const layout = splash.constants.layout;
const palette = splash.constants.palette;

pub fn paint(canvas: *Canvas, state: *const SplashState) TextError!void {
    splash.panel.fillBackground(canvas);
    splash.panel.drawBrackets(canvas);
    try splash.wordmark.render(canvas);
    try drawRomaji(canvas);
    try drawFooter(canvas);
    try refresh(canvas, state);
}

pub fn refresh(canvas: *Canvas, state: *const SplashState) TextError!void {
    try splash.trail.render(canvas, state);
    splash.progress.render(canvas, state);
}

fn drawRomaji(canvas: *Canvas) TextError!void {
    const style = Canvas.styleFor(layout.ROMAJI_SIZE, layout.ROMAJI_TRACKING);

    try graphics.text.drawString(
        canvas.Renderer,
        &canvas.Surface,
        &canvas.Face,
        style,
        try splash.measure.centredOrigin(canvas, style, labels.ROMAJI),
        canvas.RomajiBaseline,
        labels.ROMAJI,
        palette.DIM_CHROME,
        palette.BACKGROUND,
    );
}

fn drawFooter(canvas: *Canvas) TextError!void {
    const style = Canvas.styleFor(layout.FOOTER_SIZE, layout.FOOTER_TRACKING);
    const right_width = try splash.measure.width(canvas, style, labels.FOOTER_RIGHT);

    try graphics.text.drawString(
        canvas.Renderer,
        &canvas.Surface,
        &canvas.Face,
        style,
        canvas.FooterLeftX,
        canvas.FooterBaseline,
        labels.FOOTER_LEFT,
        palette.FOOTER,
        palette.BACKGROUND,
    );

    try graphics.text.drawString(
        canvas.Renderer,
        &canvas.Surface,
        &canvas.Face,
        style,
        canvas.FooterRightX - right_width,
        canvas.FooterBaseline,
        labels.FOOTER_RIGHT,
        palette.FOOTER,
        palette.BACKGROUND,
    );
}
