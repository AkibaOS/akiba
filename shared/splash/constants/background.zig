//! Embedded Splash Background

const labels = @import("shared").splash.strings.splash;

pub const PIXELS = @embedFile("../assets/hikari.rgb");
pub const WIDTH: i32 = 1585;
pub const HEIGHT: i32 = 992;
pub const CHANNELS: usize = 3;

comptime {
    if (PIXELS.len != @as(usize, WIDTH) * @as(usize, HEIGHT) * CHANNELS) {
        @compileError(labels.INVALID_BACKGROUND);
    }
}
