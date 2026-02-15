//! Invocation numbers and constants

pub const EXIT: u64 = 0x01;
pub const ATTACH: u64 = 0x02;
pub const SEAL: u64 = 0x03;
pub const VIEW: u64 = 0x04;
pub const MARK: u64 = 0x05;
pub const SPAWN: u64 = 0x06;
pub const WAIT: u64 = 0x07;
pub const YIELD: u64 = 0x08;
pub const GETKEYCHAR: u64 = 0x09;
pub const VIEWSTACK: u64 = 0x0A;
pub const GETLOCATION: u64 = 0x0B;
pub const SETLOCATION: u64 = 0x0C;
pub const POSTMAN: u64 = 0x0D;
pub const WIPE: u64 = 0x0E;

/// Error return value for invocations (-1 as unsigned)
pub const ERROR: u64 = @as(u64, @bitCast(@as(i64, -1)));

/// No data available (used by getkeychar)
pub const NO_DATA: u64 = @as(u64, @bitCast(@as(i64, -2)));
