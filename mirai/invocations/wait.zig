//! Wait invocation - Wait for child Kata to exit

const handler = @import("handler.zig");
const kata_mod = @import("../kata/kata.zig");
const sensei = @import("../kata/sensei.zig");

pub fn invoke(ctx: *handler.InvocationContext) void {
    const target_id = @as(u32, @truncate(ctx.rdi));

    const target = kata_mod.get_kata(target_id) orelse {
        ctx.rax = @as(u64, @bitCast(@as(i64, -1)));
        return;
    };

    if (target.state == .Dissolved) {
        ctx.rax = target.exit_code;
        return;
    }

    const current = sensei.get_current_kata() orelse {
        ctx.rax = @as(u64, @bitCast(@as(i64, -1)));
        return;
    };

    current.state = .Waiting;
    current.waiting_for = target_id;

    // Save context before scheduling
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
