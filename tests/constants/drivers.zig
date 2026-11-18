//! Bounded Device Probe Inputs

pub const WAIT_LIMIT: usize = 100000000;
pub const REQUIRED_TICKS: u64 = 2;
pub const INPUT_WAIT_TICKS: u64 = 8000;
pub const BREAK_MASK: u8 = 0x80;
pub const TERMINATOR_MAKE: u8 = 0x1e;
pub const BREAK_CODE: u8 = TERMINATOR_MAKE | BREAK_MASK;
pub const CHALLENGE_TAPS = 6;
pub const MAKE_CODES = [_]u8{ 0x30, 0x2e, 0x20, 0x12, 0x21, 0x22, 0x23, 0x24, 0x25, 0x26, 0x32, 0x31, 0x19, 0x13, 0x14, 0x2f };
