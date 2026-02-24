//! Invocation result utilities

const invocations = @import("../../common/constants/invocations.zig");
const handler = @import("../../invocations/handler.zig");

pub const ERROR = invocations.ERROR;
pub const NO_DATA = invocations.NO_DATA;

pub inline fn set_error(ctx: *handler.InvocationContext) void {
    ctx.rax = ERROR;
}

pub inline fn set_no_data(ctx: *handler.InvocationContext) void {
    ctx.rax = NO_DATA;
}

pub inline fn set_ok(ctx: *handler.InvocationContext) void {
    ctx.rax = 0;
}

pub inline fn set_value(ctx: *handler.InvocationContext, value: u64) void {
    ctx.rax = value;
}

pub inline fn is_error(value: u64) bool {
    return value == ERROR;
}
