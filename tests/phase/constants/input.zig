//! Shared Device Input Challenge Values

pub const BREAK_MASK: u8 = 0x80;
pub const TERMINATOR_MAKE: u8 = 0x1e;
pub const BREAK_CODE: u8 = TERMINATOR_MAKE | BREAK_MASK;
pub const CHALLENGE_TAPS = 6;
pub const EDITING_MAKE: u8 = 0x0e;
pub const TEXT_KIND: u8 = 0;
pub const EDITING_KIND: u8 = 1;
pub const BACKSPACE_EVENT: u32 = 1;
pub const EVENT_COUNT = CHALLENGE_TAPS + 2;
pub const MAKE_CODES = [_]u8{ 0x30, 0x2e, 0x20, 0x12, 0x21, 0x22, 0x23, 0x24, 0x25, 0x26, 0x32, 0x31, 0x19, 0x13, 0x14, 0x2f };
