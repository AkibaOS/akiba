//! Yield invocation - Voluntarily give up CPU time to Sensei

const handler = @import("../handler.zig");
const kata_mod = @import("../../kata/kata.zig");
const result = @import("../../utils/types/result.zig");
const sensei = @import("../../kata/sensei/sensei.zig");

pub fn invoke(ctx: *handler.InvocationContext) void {
    const kata = sensei.get_current_kata() orelse return result.set_error(ctx);

    kata.state = kata_mod.State.Alive;

    // Save context before switching - schedule() may not return
    kata.context.rax = 0; // Return value for yield
    kata.context.rbx = ctx.rbx;
    kata.context.rcx = ctx.rcx;
    kata.context.rdx = ctx.rdx;
    kata.context.rsi = ctx.rsi;
    kata.context.rdi = ctx.rdi;
    kata.context.rbp = ctx.rbp;
    kata.context.rsp = ctx.rsp;
    kata.context.r8 = ctx.r8;
    kata.context.r9 = ctx.r9;
    kata.context.r10 = ctx.r10;
    kata.context.r11 = ctx.r11;
    kata.context.r12 = ctx.r12;
    kata.context.r13 = ctx.r13;
    kata.context.r14 = ctx.r14;
    kata.context.r15 = ctx.r15;
    kata.context.rip = ctx.rip;
    kata.context.rflags = ctx.rflags;
    kata.context.cs = ctx.cs;
    kata.context.ss = ctx.ss;

    if (!sensei.is_in_queue(kata)) {
        sensei.enqueue_kata(kata);
    }

    sensei.schedule();

    result.set_ok(ctx);
}
