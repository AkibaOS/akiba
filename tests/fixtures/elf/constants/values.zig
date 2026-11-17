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
pub const OPAQUE_ARGUMENT: u64 = 0x13579bdf2468ace0;
pub const PAGE_SIZE = 4096;
pub const RODATA_REPETITIONS = 745;
pub const SUCCESS: u64 = 0x123456789abcdef0;
