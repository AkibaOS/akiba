//! Wait invocation - Wait for child Kata to dissolve

const handler = @import("../handler.zig");
const int = @import("../../utils/types/int.zig");
const kata_mod = @import("../../kata/kata.zig");
const result = @import("../../utils/types/result.zig");
const sensei = @import("../../kata/sensei.zig");

pub fn invoke(ctx: *handler.InvocationContext) void {
    const target_id = int.u32_of(ctx.rdi);

    const target = kata_mod.get_kata(target_id) orelse return result.set_error(ctx);

    if (target.state == .Dissolved) {
        return result.set_value(ctx, target.exit_code);
    }

    const current = sensei.get_current_kata() orelse return result.set_error(ctx);

    current.state = .Waiting;
    current.waiting_for = target_id;

    current.context.rax = 0;
    current.context.rbx = ctx.rbx;
    current.context.rcx = ctx.rcx;
    current.context.rdx = ctx.rdx;
    current.context.rsi = ctx.rsi;
    current.context.rdi = ctx.rdi;
    current.context.rbp = ctx.rbp;
    current.context.rsp = ctx.rsp;
    current.context.r8 = ctx.r8;
    current.context.r9 = ctx.r9;
    current.context.r10 = ctx.r10;
    current.context.r11 = ctx.r11;
    current.context.r12 = ctx.r12;
    current.context.r13 = ctx.r13;
    current.context.r14 = ctx.r14;
    current.context.r15 = ctx.r15;
    current.context.rip = ctx.rip;
    current.context.rflags = ctx.rflags;
    current.context.cs = ctx.cs;
    current.context.ss = ctx.ss;

    sensei.schedule();
}
