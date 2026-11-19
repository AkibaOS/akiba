//! Real Request Bound Weaver Diagnostic Values

pub const HEAP_BYTES: usize = 256 * 1024;
pub const SERVER_STACK: u64 = 0x90000000;
pub const SERVER_STACK_PAGES: u64 = 16;
pub const STARTUP_ADDRESS: u64 = 0x71000000;
pub const PARAMETER_COUNT: usize = 4097;
pub const PARAMETER_BYTE: u8 = 0xa5;
pub const PARAMETER_LAST: u8 = 0x69;
pub const VERIFIED_STARTUP_RESULT: u64 = 0x100;
pub const REJECTED_STARTUP_RESULT: u64 = 0xffff;
pub const EXPECTED_RESULT: u64 = 0x10f;
pub const RECEIVE: u64 = 3;
pub const REPLY: u64 = 5;
pub const INVALID_ADDRESS: u64 = 4;
