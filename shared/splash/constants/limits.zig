//! Splash Limits

const layout = @import("shared").splash.constants.layout;

pub const TRAIL_LINES: usize = 3;
pub const FAILED_TRAIL_LINES: usize = 2;
pub const TRAIL_BUFFER_WIDTH: usize = @intCast(layout.RULE_WIDTH);
pub const TRAIL_BUFFER_HEIGHT: usize = @intCast(layout.TRAIL_STEP * @as(i32, @intCast(TRAIL_LINES - 1)) + layout.TRAIL_SIZE + layout.TRAIL_DESCENT);
pub const TRAIL_BUFFER_PIXELS: usize = TRAIL_BUFFER_WIDTH * TRAIL_BUFFER_HEIGHT;

pub const MESSAGE_CAPACITY: usize = 64;

pub const BOOT_STEPS: u8 = 18;
