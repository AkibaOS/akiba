//! Kernel Splash Continuation

const boot = @import("shared").boot;
const font = @import("shared").font;
const graphics = @import("shared").graphics;
const splash = @import("shared").splash;

const BootParams = boot.types.params.BootParams;
const Canvas = splash.types.canvas.Canvas;
const SplashState = splash.types.state.SplashState;
const Surface = graphics.types.surface.Surface;
const TextRenderer = graphics.types.renderer.TextRenderer;

var canvas: Canvas = undefined;
var renderer: TextRenderer = undefined;
var state: SplashState = SplashState.initialize(0);
var ready: bool = false;

pub fn adopt(boot_params: *const BootParams) bool {
    if (!boot_params.Splash.isActive()) {
        return false;
    }

    const info = boot_params.Framebuffer;
    if (info.Base == 0 or info.Width == 0 or info.Height == 0) {
        return false;
    }

    const face = font.face.load(graphics.assets.font.HIKARI) catch return false;

    canvas = Canvas.initialize(
        Surface.initialize(info.Base, info.Width, info.Height, info.Stride, info.PixelFormat),
        face,
        &renderer,
    );
    state = boot_params.Splash;
    ready = true;
    return true;
}

pub fn report(message: []const u8) void {
    if (!ready) {
        return;
    }
    state.pushMessage(message);
    splash.render.refresh(&canvas, &state) catch {};
}

pub fn fail(message: []const u8) void {
    if (!ready) {
        return;
    }
    state.Failed = 1;
    state.pushMessage(message);
    splash.render.refresh(&canvas, &state) catch {};
}

pub fn isReady() bool {
    return ready;
}
