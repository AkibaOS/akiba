//! Compiler Fixture Values

pub const BAD_ARGUMENT: u64 = 1;
pub const BAD_DATA: u64 = 2;
pub const BAD_RODATA: u64 = 3;
pub const BAD_BSS_ZERO: u64 = 4;
pub const BAD_BSS_WRITE: u64 = 5;
pub const BAD_PANIC: u64 = 6;
pub const BSS_LENGTH: usize = 8193;
pub const BSS_MASK: u8 = 0xa7;
pub const BSS_SHIFT = 8;
pub const DATA_REPETITIONS = 1171;
pub const STARTUP_VERSION: u64 = 1;
pub const STARTUP_FIELDS: usize = 3;
pub const STARTUP_PARAMETER_BYTES: usize = 2 * PAGE_SIZE + 37;
pub const STARTUP_PARAMETER_MASK: u8 = 0x69;
pub const USER_LAST: u64 = 0x7fffffffffff;
pub const PROVISION_IDENTITY: u8 = 0x57;
pub const PROVISION_PARAMETER: u8 = 0xa5;
pub const PROVISION_RESULT: u64 = 0x3456fedc789abcde;
pub const PAGE_SIZE = 4096;
pub const RODATA_REPETITIONS = 745;
pub const SUCCESS: u64 = 0x123456789abcdef0;
