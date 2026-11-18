//! Crimson Regression Inputs

const types = @import("tests").types.crimson;

pub const VECTORS = [_]types.VectorCase{
    .{ .Number = 0, .Kind = .Overflow, .ErrorCode = false },
    .{ .Number = 6, .Kind = .Forbidden, .ErrorCode = false },
    .{ .Number = 8, .Kind = .Collapse, .ErrorCode = true },
    .{ .Number = 14, .Kind = .Breach, .ErrorCode = true },
    .{ .Number = 18, .Kind = .Collapse, .ErrorCode = false },
    .{ .Number = 31, .Kind = .Forbidden, .ErrorCode = false },
};
pub const ACTIONS = [_]types.ActionCase{
    .{ .Code = 0, .Action = .Resume, .Modify = false },
    .{ .Code = 1, .Action = .Skip, .Modify = false },
    .{ .Code = 2, .Action = .Terminate, .Modify = false },
    .{ .Code = 3, .Action = .TerminateCorpse, .Modify = false },
    .{ .Code = 4, .Action = .Collapse, .Modify = false },
    .{ .Code = 5, .Action = .Debug, .Modify = false },
    .{ .Code = 0x100, .Action = .Resume, .Modify = true },
};
pub const THREAD_ID: u64 = 1023;
pub const KATA_ID: u64 = 255;
pub const PORT_HIGH_IDS = [_]u64{ 256, 1024, 0x10000000000, 0xFFFFFFFFFFFFFFFF };
pub const PORT_UNUSED_ID: u64 = 0xFFFFFFFFFFFFFFFE;
pub const PORT_GROWTH_COUNT: usize = 1100;
pub const PORT_GROWTH_BASE: u64 = 0x100000000000;
pub const PORT_FAILURE_BASE: u64 = 0x200000000000;
pub const PORT_OWNER_STRIDE: u64 = 4099;
pub const PORT_FAILURE_LIMIT: usize = 1100;
pub const PORT_GROWTH_KATA: u64 = 0x1000000;
pub const PORT_GROWTH_THREAD: u64 = 0x2000000;
pub const PORT_UPDATED_KATA: u64 = 0x404;
pub const PORT_UPDATED_THREAD: u64 = 0x505;
pub const HOST_PORT: u64 = 0x101;
pub const KATA_PORT: u64 = 0x202;
pub const THREAD_PORT: u64 = 0x303;
pub const EXCEPTION_CODE: u64 = 0x8877665544332211;
pub const FAULT_ADDRESS: u64 = 0x3000000;
pub const CONTEXT_RAX: u64 = 0x123456789abcdef0;
pub const INVALID_ACTION: u64 = 0xff;
pub const MODULE_LONG_NAME = [_]u8{0x78} ** 64;
pub const MODULE_BASE: u64 = 0xABC000;
pub const MODULE_SIZE: u64 = 4096;
