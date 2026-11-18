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
const Workspace = splash.types.workspace.Workspace;

var canvas: Canvas = undefined;
var renderer: TextRenderer = undefined;
var workspace: Workspace = undefined;
var state: SplashState = SplashState.initialize(0);
var ready: bool = false;

pub fn adopt(info: FramebufferInfo, initial_state: SplashState) bool {
    if (!initial_state.isActive() or !initial_state.isValid() or !info.isValid()) return false;

    const face = font.face.load(graphics.assets.font.HIKARI) catch return false;
    renderer = workspace.bind();

    canvas = Canvas.initialize(
        Surface.initialize(info.Base, info.Width, info.Height, info.Stride, info.PixelFormat),
        face,
        &renderer,
    ) orelse return false;
    state = initial_state;
    ready = true;
    return true;
}

pub fn report(message: []const u8) void {
    if (!ready) {
        return;
    }
    state.pushMessage(message);
    canvas.ActivityFrame +%= 1;
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
