//! Guest Regression Inputs

pub const CODE_ADDRESS: u64 = 0x400000;
pub const DATA_ADDRESS: u64 = 0x500000;
pub const STACK_ADDRESS: u64 = 0x800000;
pub const EXIT_RESULT: u64 = 37;
pub const ENTRY_ARGUMENT: u64 = 42;
pub const INVALID_OPCODE_VECTOR: u64 = 6;
pub const INVALID_OPCODE = [_]u8{ 0x0f, 0x0b };
pub const PAYLOAD = [_]u8{ 1, 2, 3, 4 };
pub const REPLACEMENT = [_]u8{ 5, 6, 7, 8 };
pub const DRIVE_LIMIT: usize = 1024;
