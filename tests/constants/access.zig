//! Persona Hardware Access Probe Inputs

pub const DATA_ADDRESS: u64 = 0xa00000;
pub const ADDRESS_OFFSET: usize = 2;
pub const OPERAND_BYTES: usize = 8;
pub const INSTRUCTION_OFFSET: u64 = 10;
pub const PAGE_FAULT_VECTOR: u64 = 14;
pub const WRITE_ERROR: u64 = 7;
pub const EXECUTE_ERROR: u64 = 21;
pub const SUPERVISOR_ERROR: u64 = 5;
pub const WRITE = [_]u8{ 0x48, 0xb8, 0, 0, 0, 0, 0, 0, 0, 0, 0xc6, 0x00, 0x5a, 0x0f, 0x0b };
pub const EXECUTE = [_]u8{ 0x48, 0xb8, 0, 0, 0, 0, 0, 0, 0, 0, 0xff, 0xe0 };
pub const READ = [_]u8{ 0x48, 0xb8, 0, 0, 0, 0, 0, 0, 0, 0, 0x48, 0x8b, 0x00, 0x0f, 0x0b };
pub const RETURN = [_]u8{0xc3};
