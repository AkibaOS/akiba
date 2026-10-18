//! Kernel Splash Continuation

const boot = @import("shared").boot;
const font = @import("shared").font;
const graphics = @import("shared").graphics;
const splash = @import("shared").splash;

const FramebufferInfo = boot.types.framebuffer.FramebufferInfo;
const Canvas = splash.types.canvas.Canvas;
const SplashState = splash.types.state.SplashState;
const Surface = graphics.types.surface.Surface;
const TextRenderer = graphics.types.renderer.TextRenderer;

var canvas: Canvas = undefined;
var renderer: TextRenderer = undefined;
var state: SplashState = SplashState.initialize(0);
var ready: bool = false;

pub fn adopt(info: FramebufferInfo, initial_state: SplashState) bool {
    if (!initial_state.isActive()) return false;
    const row_bytes = @as(u64, info.Stride) * @sizeOf(u32);
    if (info.Base == 0 or info.Size == 0 or info.Width == 0 or info.Height == 0 or
        info.Stride < info.Width or row_bytes == 0 or info.Height > info.Size / row_bytes or
        (info.PixelFormat != .RGB and info.PixelFormat != .BGR))
    {
        return false;
    }

    const face = font.face.load(graphics.assets.font.HIKARI) catch return false;

    canvas = Canvas.initialize(
        Surface.initialize(info.Base, info.Width, info.Height, info.Stride, info.PixelFormat),
        face,
        &renderer,
    );
    state = initial_state;
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
