//! QEMU Firmware Configuration Bounds

pub const SELECT_PORT: u16 = 0x510;
pub const DATA_PORT: u16 = 0x511;
pub const SIGNATURE_SELECTOR: u16 = 0;
pub const DIRECTORY_SELECTOR: u16 = 0x19;
pub const ENTRY_BYTES: usize = 64;
pub const NAME_OFFSET: usize = 8;
pub const MAX_FILES: u32 = 256;
pub const MAX_VALUE_BYTES: usize = 32;
pub const SIGNATURE = [_]u8{ 'Q', 'E', 'M', 'U' };
