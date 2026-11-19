//! EFI Diagnostic Menu Timing And Input Constants

const std = @import("std");

pub const NO_SCAN_CODE: u16 = 0;
pub const ENTER: u16 = '\r';
pub const SHUTDOWN_LOWER: u16 = 's';
pub const SHUTDOWN_UPPER: u16 = 'S';
pub const INPUT_POLL_MICROSECONDS: usize = 10 * std.time.us_per_ms;

pub const SERIAL_POLL_MICROSECONDS: usize = 100;
pub const SERIAL_RECEIVE_POLLS: usize = 10 * std.time.us_per_s / SERIAL_POLL_MICROSECONDS;
pub const SERIAL_SEND_POLLS: usize = 250 * std.time.us_per_ms / SERIAL_POLL_MICROSECONDS;
pub const SERIAL_TRANSMITTER_EMPTY: u8 = 0x40;
pub const SERIAL_UNAVAILABLE: u8 = 0xff;
