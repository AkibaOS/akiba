//! Persona Postman Regression Fixtures

pub const CODE_BASE: u64 = 0x400000;
pub const DATA_BASE: u64 = 0x500000;
pub const STACK_BASE: u64 = 0x800000;
pub const PAGE_BYTES: usize = 4096;
pub const MAX_STEPS: usize = 16;
pub const GROWTH_PAIRS: usize = 17;
pub const RESULT_OFFSET: u64 = 16;
pub const INPUT_OFFSET: u64 = 512;
pub const OUTPUT_OFFSET: u64 = 768;
pub const HEADER_OFFSET: u64 = 1024;
pub const CALL_OFFSET: u64 = 1280;
pub const TICKET_OFFSET: u64 = 384;
pub const OUTPUT_BYTES: usize = 64;
pub const GUARD_BYTE: u8 = 0xD7;
pub const INVALID_ADDRESS: u64 = 0x600000;
pub const INVALID_PEER: u64 = 0xFFFFFFFFFFFFFFFF;
pub const PROVISION_SERVICE: u64 = 13;
pub const PROVISION_BEGIN: u64 = 0;
pub const PROVISION_ABORT: u64 = 1;
pub const PROVISION_ALLOCATE: u64 = 2;
pub const PROVISION_LOAD: u64 = 3;
pub const PROVISION_SEAL: u64 = 4;
pub const PROVISION_START: u64 = 5;
pub const PROVISION_RETAIN: u64 = 6;
pub const PROVISION_ATTACH: u64 = 7;
pub const PROVISION_READ: u64 = 0;
pub const PROVISION_WRITE: u64 = 1;
pub const PROVISION_EXECUTE: u64 = 2;
pub const PROVISION_RESULT: u64 = 0x3456fedc789abcde;
pub const PROVISION_STARTUP = [_]u8{
    1,    0,    0, 0, 0, 0, 0, 0,
    1,    0,    0, 0, 0, 0, 0, 0,
    1,    0,    0, 0, 0, 0, 0, 0,
    0x57, 0xa5,
};
pub const LETTER_TYPE: u64 = 0x4123;
pub const SECOND_TYPE: u64 = 0x4124;
pub const REQUEST = [_]u8{ 0x31, 0x00, 0xFE, 0x7F, 0x80, 0xA5, 0x19, 0x42 };
pub const REPLACEMENT = [_]u8{ 0xE1, 0x21, 0x02, 0x00, 0x19, 0x82, 0x7E, 0x13 };
pub const REPLY = [_]u8{ 0x55, 0xAA, 0x00, 0xFF, 0x10, 0x20, 0x30, 0x40 };
pub const MOV_RAX = [_]u8{ 0x48, 0xB8 };
pub const MOV_RDI = [_]u8{ 0x48, 0xBF };
pub const MOV_RSI = [_]u8{ 0x48, 0xBE };
pub const MOV_RDX = [_]u8{ 0x48, 0xBA };
pub const MOV_R10 = [_]u8{ 0x49, 0xBA };
pub const MOV_R11 = [_]u8{ 0x49, 0xBB };
pub const LOAD_RDI = [_]u8{ 0x48, 0x8B, 0x3F };
pub const INVOKE = [_]u8{ 0xCD, 0x80 };
pub const STORE_RESULT = [_]u8{ 0x49, 0x89, 0x03, 0x49, 0x89, 0x53, 0x08 };
pub const STORE_RAX = [_]u8{ 0x49, 0x89, 0x03 };
pub const COMPARE_GATE = [_]u8{ 0x49, 0x83, 0x3B };
pub const JUMP_BELOW: u8 = 0x72;
pub const INVALID_OPCODE = [_]u8{ 0x0F, 0x0B };
