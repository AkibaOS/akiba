//! Diagnostic Screen Text Mode Palette

const Color = @import("shared").graphics.types.color.Color;

pub const DESKTOP = Color.rgb(0, 0, 0);
pub const BORDER = DESKTOP;
pub const TERMINAL = DESKTOP;
pub const TITLE_BAR = Color.rgb(0, 0, 170);
pub const TITLE_TEXT = Color.rgb(255, 255, 255);
pub const SUBTITLE_TEXT = Color.rgb(170, 170, 170);
pub const INFORMATION = Color.rgb(170, 170, 170);
pub const PASSED = Color.rgb(85, 255, 85);
pub const FAILED = Color.rgb(255, 85, 85);
pub const RUNNING = Color.rgb(255, 255, 85);
pub const BAR_FILL = Color.rgb(85, 85, 255);
pub const CAPTION = Color.rgb(170, 170, 170);
pub const ACTIVE_CONTROL = TITLE_TEXT;
pub const INACTIVE = Color.rgb(128, 128, 128);
