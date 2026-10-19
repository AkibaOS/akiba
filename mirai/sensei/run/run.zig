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
const thread = @import("mirai").thread;
const types = @import("mirai").sensei.types;

const Record = types.record.Record;
const SchedulingError = errors.SchedulingError;
const Thread = thread.types.thread.Thread;

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

fn takeReady(preferred: ?*Thread, current: *Record, idle: *Record) ?*Record {
    const scheduler = state.getState();
    const target = preferred orelse return queue.take(&scheduler.Ready);
    if (!thread.state.owns(target) or !target.Managed or target.Status != .Ready) @panic(messages.INVALID_STATE);
    const record = registry.find(target) orelse @panic(messages.INVALID_STATE);
    if (record == idle or record == current or record.Queue != &scheduler.Ready) @panic(messages.INVALID_STATE);
    if (!queue.remove(&scheduler.Ready, record)) @panic(messages.INVALID_QUEUE);
    return record;
}

pub fn reschedule(blocked: bool) void {
    rescheduleTo(blocked, null);
}

pub fn rescheduleTo(blocked: bool, preferred: ?*Thread) void {
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
    const next = takeReady(preferred, current, idle) orelse if (blocked) idle else {
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

pub fn stopCurrent() noreturn {
    const scheduler = state.getState();
    if (!scheduler.Initialized or (cpu.readFlags() & control.RFLAGS_INTERRUPT_ENABLE) != 0 or
        scheduler.IRQDepth != 0 or scheduler.PreemptionDepth != 0) @panic(messages.INVALID_STATE);
    const current = registry.current() orelse @panic(messages.INVALID_STATE);
    const previous = current.Thread orelse @panic(messages.INVALID_STATE);
    const idle = scheduler.Idle orelse @panic(messages.INVALID_STATE);
    if (!thread.state.owns(previous) or !previous.Managed or previous.Permanent or previous.Status != .Running or
        current == idle or current.Queue != null or current.Next != null) @panic(messages.INVALID_STATE);
    if (!queue.append(&scheduler.Retired, current)) @panic(messages.INVALID_QUEUE);
    const next = queue.take(&scheduler.Ready) orelse idle;
    if (next == current or next.Queue != null) @panic(messages.INVALID_STATE);
    const target = next.Thread orelse @panic(messages.INVALID_STATE);
    if (!target.Managed or target.Status != .Ready) @panic(messages.INVALID_STATE);
    scheduler.Pending = false;
    scheduler.RemainingTicks = policy.QUANTUM_TICKS;
    scheduler.Switches +%= 1;
    shift.dispatch(target, .Stopped) catch @panic(messages.INVALID_TRANSFER);
    @panic(messages.INVALID_TRANSFER);
}
