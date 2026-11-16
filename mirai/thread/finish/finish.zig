//! Normal Individual Thread Completion

const guard = @import("asm").interrupts.guard;
const kata = @import("mirai").kata;
const messages = @import("mirai").thread.strings.shift.messages;
const sensei = @import("mirai").sensei;
const state = @import("mirai").thread.state;

pub fn complete() noreturn {
    _ = guard.acquire();
    const current = state.getCurrent() orelse @panic(messages.INVALID_CONTEXT);
    if (!state.owns(current) or !current.Admitted or !current.Managed or current.Permanent or
        current.Status != .Running or !kata.state.owns(current.Owner) or current.Owner.State != .Alive or
        current.Owner.LiveThreadCount == 0) @panic(messages.INVALID_CONTEXT);
    if (current.Owner.LiveThreadCount == 1) kata.finish.normal();
    sensei.run.stopCurrent();
}
