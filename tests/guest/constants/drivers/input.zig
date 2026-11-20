//! Bounded Device Probe Inputs

pub const WAIT_LIMIT: usize = 100000000;
pub const REQUIRED_TICKS: u64 = 2;
pub const INPUT_WAIT_TICKS: u64 = 8000;
pub const ESCAPE_MAKE: u8 = 0x01;
pub const KEYBOARD_OUTPUT_READY: u8 = 0x01;
pub const KEYBOARD_OUTPUT_MASK: u8 = 0xe1;
