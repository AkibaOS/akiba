//! Hikari Splash Session

const console = @import("hikari").sequence.console;
const efi = @import("hikari").efi;
const graphics = @import("shared").graphics;
const splash = @import("shared").splash;

const Canvas = splash.types.canvas.Canvas;
const Font = graphics.types.font.Font;
const SplashState = splash.types.state.SplashState;
const Surface = graphics.types.surface.Surface;

const limits = splash.constants.limits;

var canvas: Canvas = undefined;
var state: SplashState = SplashState.initialize(limits.BOOT_STEPS);
var ready: bool = false;
var fallback: ?*efi.protocols.output.SimpleTextOutputProtocol = null;

pub fn initialize(
    gop: *efi.protocols.graphics.GraphicsOutputProtocol,
    console_output: *efi.protocols.output.SimpleTextOutputProtocol,
) bool {
    fallback = console_output;

    const mode = gop.Mode;
    const info = mode.Info;

    if (mode.FramebufferBase == 0 or mode.FramebufferSize == 0) {
        return false;
    }
    if (info.HorizontalResolution == 0 or info.VerticalResolution == 0) {
        return false;
    }
    if (info.PixelFormat != .RGB and info.PixelFormat != .BGR) {
        return false;
    }

    const font = Font.load(&graphics.assets.font.DEFAULT, graphics.assets.font.DEFAULT.len) orelse return false;

    const surface = Surface.initialize(
        mode.FramebufferBase,
        info.HorizontalResolution,
        info.VerticalResolution,
        info.PixelsPerScanLine,
        switch (info.PixelFormat) {
            .RGB => .RGB,
            .BGR => .BGR,
            else => .Unknown,
        },
    );

    canvas = Canvas.initialize(surface, font);
    state.Active = 1;
    ready = true;

    splash.render.paint(&canvas, &state);
    return true;
}

pub fn report(message: []const u8) void {
    if (!ready) {
        reportToFirmware(message);
        return;
    }
    state.pushMessage(message);
    splash.render.refresh(&canvas, &state);
}

pub fn fail(message: []const u8) void {
    if (!ready) {
        reportToFirmware(message);
        return;
    }
    state.Failed = 1;
    state.pushMessage(message);
    splash.render.refresh(&canvas, &state);
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
