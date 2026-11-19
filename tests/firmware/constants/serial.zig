//! Firmware Live UART Polling Limits

const std = @import("std");

pub const POLL_MICROSECONDS: usize = 100;
pub const RECEIVE_POLLS: usize = 10 * std.time.us_per_s / POLL_MICROSECONDS;
pub const SEND_POLLS: usize = 250 * std.time.us_per_ms / POLL_MICROSECONDS;
pub const TRANSMITTER_EMPTY: u8 = 0x40;
pub const UNAVAILABLE: u8 = 0xff;
