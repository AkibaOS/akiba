//! Hikari Splash Session

const boot = @import("shared").boot;
const console = @import("hikari").sequence.console;
const efi = @import("hikari").efi;
const font = @import("shared").font;
const graphics = @import("shared").graphics;
const splash = @import("shared").splash;

const Canvas = splash.types.canvas.Canvas;
const SplashState = splash.types.state.SplashState;
const Surface = graphics.types.surface.Surface;
const TextRenderer = graphics.types.renderer.TextRenderer;

const limits = splash.constants.limits;

var canvas: Canvas = undefined;
var renderer: TextRenderer = undefined;
var state: SplashState = SplashState.initialize(limits.BOOT_STEPS);
var ready: bool = false;
var fallback: ?*efi.types.protocols.output.SimpleTextOutputProtocol = null;

pub fn initialize(
    framebuffer: boot.types.framebuffer.FramebufferInfo,
    console_output: *efi.types.protocols.output.SimpleTextOutputProtocol,
) bool {
    fallback = console_output;
    ready = false;
    state = SplashState.initialize(limits.BOOT_STEPS);
    if (!framebuffer.isValid()) return false;

    const face = font.face.load(graphics.assets.font.HIKARI) catch return false;
    const surface = Surface.initialize(framebuffer.Base, framebuffer.Width, framebuffer.Height, framebuffer.Stride, framebuffer.PixelFormat);
    canvas = Canvas.initialize(surface, face, &renderer) orelse return false;
    splash.render.paint(&canvas, &state) catch return false;
    state.Active = 1;
    ready = true;
    return true;
}

pub fn report(message: []const u8) void {
    if (!ready) {
        reportToFirmware(message);
        return;
    }
    state.pushMessage(message);
    canvas.ActivityFrame +%= 1;
    splash.render.refresh(&canvas, &state) catch {};
}

pub fn fail(message: []const u8) void {
    if (!ready) {
        reportToFirmware(message);
        return;
    }
    state.Failed = 1;
    state.pushMessage(message);
    splash.render.refresh(&canvas, &state) catch {};
}

fn reportToFirmware(message: []const u8) void {
    if (fallback) |output| {
        console.print(output, message);
    }
}

pub fn isReady() bool {
    return ready;
}

pub fn getState() *const SplashState {
    return &state;
}
