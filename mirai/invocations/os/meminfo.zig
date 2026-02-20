//! MEMINFO invocation - Get memory information

const handler = @import("../handler.zig");
const memory = @import("../../common/constants/memory.zig");
const pmm = @import("../../memory/pmm.zig");
const result = @import("../../utils/types/result.zig");

pub fn invoke(ctx: *handler.InvocationContext) void {
    const total_ptr: *u64 = @ptrFromInt(ctx.rdi);
    const used_ptr: *u64 = @ptrFromInt(ctx.rsi);
    const free_ptr: *u64 = @ptrFromInt(ctx.rdx);

    const info = pmm.get_info();

    total_ptr.* = info.total * memory.PAGE_SIZE;
    used_ptr.* = info.used * memory.PAGE_SIZE;
    free_ptr.* = (info.total - info.used) * memory.PAGE_SIZE;

    result.set_ok(ctx);
}
