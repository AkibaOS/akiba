//! EFI Diagnostic Menu Timing And Input Constants

const std = @import("std");

pub const NO_SCAN_CODE: u16 = 0;
pub const ENTER: u16 = '\r';
pub const SHUTDOWN_LOWER: u16 = 's';
pub const SHUTDOWN_UPPER: u16 = 'S';

pub const DEVICE_PATH_LIMIT: usize = 1024;
pub const DEVICE_PATH_HEADER: usize = 4;
pub const END_DEVICE_PATH: u8 = 0x7f;
pub const END_ENTIRE_PATH: u8 = 0xff;
pub const ACPI_DEVICE_PATH: u8 = 0x02;
pub const ACPI_HID_SUBTYPE: u8 = 0x01;
pub const ACPI_HID_BYTES: usize = 12;
pub const PS2_KEYBOARD_HID: u32 = 0x030341d0;

pub const SERIAL_POLL_MICROSECONDS: usize = 100;
pub const SERIAL_RECEIVE_POLLS: usize = 10 * std.time.us_per_s / SERIAL_POLL_MICROSECONDS;
pub const SERIAL_SEND_POLLS: usize = 250 * std.time.us_per_ms / SERIAL_POLL_MICROSECONDS;
pub const SERIAL_TRANSMITTER_EMPTY: u8 = 0x40;
pub const SERIAL_UNAVAILABLE: u8 = 0xff;
