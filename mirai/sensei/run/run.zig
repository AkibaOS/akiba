//! Runnable Thread Selection

const control = @import("asm").cpu.constants.control;
const cpu = @import("asm").cpu.state;
const errors = @import("mirai").sensei.errors.scheduling;
const guard = @import("asm").interrupts.guard;
const messages = @import("mirai").sensei.strings.messages;
const policy = @import("mirai").sensei.constants.policy;
const queue = @import("mirai").sensei.queue;
const registry = @import("mirai").sensei.registry;
const shift = @import("mirai").thread.shift;
const state = @import("mirai").sensei.state;

const SchedulingError = errors.SchedulingError;

pub fn canCall(previous_flags: u64) bool {
    const scheduler = state.getState();
    return scheduler.Initialized and scheduler.IRQDepth == 0 and scheduler.PreemptionDepth == 0 and
        (previous_flags & control.RFLAGS_INTERRUPT_ENABLE) != 0;
}

pub fn yield() SchedulingError!void {
    const previous_flags = guard.acquire();
    defer guard.release(previous_flags);
    if (!state.isInitialized()) return SchedulingError.NotInitialized;
    if (!canCall(previous_flags)) return SchedulingError.UnsafeContext;
    reschedule(false);
}

pub fn reschedule(blocked: bool) void {
    const scheduler = state.getState();
    if (!scheduler.Initialized) return;
    if ((cpu.readFlags() & control.RFLAGS_INTERRUPT_ENABLE) != 0) @panic(messages.INVALID_STATE);
    if (scheduler.IRQDepth != 0 or scheduler.PreemptionDepth != 0) {
        scheduler.Pending = true;
        scheduler.Deferred +%= 1;
        return;
    }
    const current = registry.current() orelse @panic(messages.INVALID_STATE);
    const previous = current.Thread orelse @panic(messages.INVALID_STATE);
    const idle = scheduler.Idle orelse @panic(messages.INVALID_STATE);
    if (!previous.Managed or previous.Status != .Running or
        (!blocked and current.Queue != null) or (blocked and (current == idle or current.Queue == null)))
        @panic(messages.INVALID_STATE);
    const next = queue.take(&scheduler.Ready) orelse if (blocked) idle else {
        scheduler.Pending = false;
        scheduler.RemainingTicks = policy.QUANTUM_TICKS;
        return;
    };
    if (next == current or next.Queue != null) @panic(messages.INVALID_STATE);
    const target = next.Thread orelse @panic(messages.INVALID_STATE);
    if (!target.Managed or target.Status != .Ready) @panic(messages.INVALID_STATE);
    if (!blocked and current != idle and !queue.append(&scheduler.Ready, current)) @panic(messages.INVALID_QUEUE);
    scheduler.Pending = false;
    scheduler.RemainingTicks = policy.QUANTUM_TICKS;
    scheduler.Switches +%= 1;
    shift.dispatch(target, if (blocked) .Blocked else .Ready) catch @panic(messages.INVALID_TRANSFER);
}
