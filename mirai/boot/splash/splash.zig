//! Kernel Splash Continuation

const boot = @import("shared").boot;
const graphics = @import("shared").graphics;
const splash = @import("shared").splash;

const Canvas = splash.types.canvas.Canvas;
const Font = graphics.types.font.Font;
const SplashState = splash.types.state.SplashState;
const Surface = graphics.types.surface.Surface;

const BootParams = boot.types.params.BootParams;

var canvas: Canvas = undefined;
var state: SplashState = SplashState.initialize(0);
var ready: bool = false;

pub fn adopt(boot_params: *const BootParams) bool {
    if (!boot_params.Splash.isActive()) {
        return false;
    }

    const font = Font.load(&graphics.assets.font.DEFAULT, graphics.assets.font.DEFAULT.len) orelse return false;
    const info = boot_params.Framebuffer;

    if (info.Base == 0 or info.Width == 0 or info.Height == 0) {
        return false;
    }

    canvas = Canvas.initialize(
        Surface.initialize(info.Base, info.Width, info.Height, info.Stride, info.PixelFormat),
        font,
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
    splash.render.refresh(&canvas, &state);
}

pub fn fail(message: []const u8) void {
    if (!ready) {
        return;
    }
    state.Failed = 1;
    state.pushMessage(message);
    splash.render.refresh(&canvas, &state);
}

pub fn isReady() bool {
    return ready;
}
