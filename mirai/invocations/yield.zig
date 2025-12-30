//! Yield invocation - voluntarily give up CPU time

const sensei = @import("../kata/sensei.zig");
const kata_mod = @import("../kata/kata.zig");
const handler = @import("handler.zig");

pub fn invoke(context: *handler.InvocationContext) void {
    const current = sensei.get_current_kata() orelse {
        context.rax = @as(u64, @bitCast(@as(i64, -1)));
        return;
    };

    // Mark current kata as READY so scheduler can pick it again
    current.state = kata_mod.KataState.Ready;

    // Trigger scheduler to pick next ready kata (might pick us again if we're only one)
    sensei.schedule();

    // Return success (execution continues here after reschedule)
    context.rax = 0;
}
