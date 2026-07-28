//! Splash Palette

const graphics = @import("shared").graphics;

const Color = graphics.types.color.Color;

pub const BACKGROUND = Color.rgb(0x0B, 0x07, 0x10);
pub const VOID = Color.rgb(0x00, 0x00, 0x00);
pub const PANEL_SCANLINE = Color.rgb(0x07, 0x04, 0x0A);
pub const WORDMARK_CORE = Color.rgb(0xF2, 0xEC, 0xFF);
pub const FRINGE_CYAN = Color.rgb(0x2E, 0xE6, 0xFF);
pub const FRINGE_MAGENTA = Color.rgb(0xFF, 0x2E, 0x88);
pub const DIM_CHROME = Color.rgb(0x8A, 0x6B, 0xA8);
pub const FRAME_BRACKET = Color.rgb(0x3A, 0x2A, 0x52);
pub const RULE_TRACK = Color.rgb(0x24, 0x18, 0x32);
pub const FOOTER = Color.rgb(0x4A, 0x3A, 0x62);

pub const TRAIL_OLDEST = Color.rgb(0x6B, 0x5A, 0x82);
pub const TRAIL_MIDDLE = Color.rgb(0xAC, 0x93, 0xC8);
pub const TRAIL_NEWEST = Color.rgb(0xF2, 0xEC, 0xFF);

pub const TRAIL = [_]Color{ TRAIL_OLDEST, TRAIL_MIDDLE, TRAIL_NEWEST };
