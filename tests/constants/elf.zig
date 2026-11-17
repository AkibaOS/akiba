//! Independent ELF Image Fixture Values

pub const PAGE_BYTES: usize = 4096;
pub const DATA_BYTES: usize = 5 * PAGE_BYTES;
pub const HEADER_BYTES: usize = 64;
pub const PROGRAM_BYTES: usize = 56;
pub const PROGRAM_COUNT: u16 = 3;
pub const CODE_ADDRESS: u64 = 0x200000;
pub const COMPILER_ENTRY: u64 = 0x400000;
pub const STACK_ADDRESS: u64 = 0x70000000;
pub const PRESSURE_ADDRESS: u64 = 0x30000000;
pub const ARGUMENT: u64 = 0x13579bdf2468ace0;
pub const EXIT_RESULT: u64 = 0x123456789abcdef0;
pub const BAD_ARGUMENT_RESULT: u64 = 1;
pub const BAD_DATA_RESULT: u64 = 2;
pub const MAXIMUM_PAGES: u64 = 32;
pub const USER_END: u64 = 0x7fffffffffff;
