//! Firmware AFS Bulk Fixture Inputs

pub const UNIT_COUNT: usize = 128;
pub const IDENTITY_BYTES: usize = 180;
pub const IDENTITY_STRIDE: usize = 2;
pub const SUFFIX_BYTES: usize = 3;
pub const NAME_BYTE: u8 = 'x';
pub const DIGIT_ZERO: u8 = '0';
pub const DECIMAL_TENS: usize = 10;
pub const DECIMAL_HUNDREDS: usize = 100;
pub const PAYLOAD_BYTES: usize = 8;
pub const PAYLOAD_INDEX_BYTES: usize = 4;
pub const PAYLOAD_SUFFIX = [_]u8{ 0xff, 0x31, 0x00, 0x7e };
