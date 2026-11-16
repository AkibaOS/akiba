//! Persona Completion Invocation Fixtures

pub const QUERY_ABI_SELECTOR: u64 = 0;
pub const QUERY_KATA_SELECTOR: u64 = 1;
pub const QUERY_INVALID_SELECTOR: u64 = 2;
pub const ABI_VERSION: u64 = 1;
pub const SERVICE_OPERAND_OFFSET: usize = 2;
pub const UNKNOWN_SERVICE: u64 = 0xffffffffffffffff;
pub const FINISH_THREAD_SERVICE: u8 = 8;
pub const EXIT_SERVICE: u8 = 9;
pub const EXIT_RESULT: u64 = 0x123456789abcdef0;
pub const INVALID_RETURN_VECTOR: u64 = 13;
pub const FINISH_THREAD = [_]u8{ 0xb8, FINISH_THREAD_SERVICE, 0, 0, 0, 0xcd, 0x80, 0x0f, 0x0b };
pub const EXIT = [_]u8{
    0x48, 0xbf,         0xf0, 0xde, 0xbc, 0x9a, 0x78, 0x56, 0x34, 0x12,
    0xb8, EXIT_SERVICE, 0,    0,    0,    0xcd, 0x80, 0x0f, 0x0b,
};
pub const BOUNDARY_FINISH = [_]u8{ 0x31, 0xe4, 0xb8, FINISH_THREAD_SERVICE, 0, 0, 0, 0xcd, 0x80 };
pub const BOUNDARY_EXIT = [_]u8{
    0x31, 0xe4, 0x48, 0xbf,         0xf0, 0xde, 0xbc, 0x9a, 0x78, 0x56,
    0x34, 0x12, 0xb8, EXIT_SERVICE, 0,    0,    0,    0xcd, 0x80,
};
pub const INVALID_QUERY = [_]u8{ 0x31, 0xe4, 0xb8, 0, 0, 0, 0, 0xcd, 0x80 };
