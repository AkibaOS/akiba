//! Crimson Regression Inputs

const limits = @import("mirai").crimson.constants.limits;
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
pub const THREAD_ID: u64 = limits.MAX_THREADS - 1;
pub const KATA_ID: u64 = limits.MAX_KATAS - 1;
pub const HOST_PORT: u64 = 0x101;
pub const KATA_PORT: u64 = 0x202;
pub const THREAD_PORT: u64 = 0x303;
pub const EXCEPTION_CODE: u64 = 0x8877665544332211;
pub const FAULT_ADDRESS: u64 = 0x3000000;
pub const CONTEXT_RAX: u64 = 0x123456789abcdef0;
pub const INVALID_ACTION: u64 = 0xff;
