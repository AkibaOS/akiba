//! Shared Device Input Witness

pub const GROUP = "CHECK GROUP Hardware devices\n";
pub const READY = "CHECK DEVICE INPUT READY";
pub const READY_LINE = READY ++ "\n";
pub const SCANCODE_PREFIX = "  Keyboard scancode 0x";
pub const KEY_NAMES = [_][]const u8{ "b", "c", "d", "e", "f", "g", "h", "j", "k", "l", "m", "n", "p", "r", "t", "v" };
pub const TERMINATOR_NAME = "a";
