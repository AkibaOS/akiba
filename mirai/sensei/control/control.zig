//! Scheduler Admission And Withdrawal

const clock = @import("mirai").sensei.clock;
const errors = @import("mirai").sensei.errors.scheduling;
const guard = @import("asm").interrupts.guard;
const messages = @import("mirai").sensei.strings.messages;
const pit = @import("mirai").drivers.pit;
const queue = @import("mirai").sensei.queue;
const registry = @import("mirai").sensei.registry;
const retire = @import("mirai").sensei.retire;
const state = @import("mirai").sensei.state;
const thread = @import("mirai").thread;

const SchedulingError = errors.SchedulingError;
const Thread = thread.types.thread.Thread;

pub fn initialize() bool {
    const previous_flags = guard.acquire();
    defer guard.release(previous_flags);
    const scheduler = state.getState();
    if (scheduler.Initialized) return false;
    const current = thread.state.getCurrent() orelse return false;
    if (!thread.state.owns(current) or !current.Permanent or current.Managed or current.Status != .Running) return false;
    const idle = registry.reserve(current) orelse return false;
    if (!thread.state.setSwitchHandler(&retire.collect)) {
        if (!registry.release(idle)) @panic(messages.INVALID_STATE);
        return false;
    }
    current.Managed = true;
    scheduler.Idle = idle;
    pit.handler.setCallback(&clock.tick);
    scheduler.Initialized = true;
    return true;
}

pub fn start(target: *Thread) SchedulingError!void {
    const previous_flags = guard.acquire();
    defer guard.release(previous_flags);
    const scheduler = state.getState();
    if (!scheduler.Initialized) return SchedulingError.NotInitialized;
    if (scheduler.IRQDepth != 0 or scheduler.PreemptionDepth != 0) return SchedulingError.UnsafeContext;
    if (!thread.state.owns(target)) return SchedulingError.InvalidThread;
    if (target.Managed or registry.find(target) != null) return SchedulingError.AlreadyManaged;
    if (target.Permanent or target.Started or target.Status != .Ready or target.EntryPoint == null)
        return SchedulingError.InvalidState;
    const record = registry.reserve(target) orelse return SchedulingError.CapacityReached;
    target.Managed = true;
    target.EnableInterrupts = true;
    if (!queue.append(&scheduler.Ready, record)) @panic(messages.INVALID_QUEUE);
    if (registry.current() == scheduler.Idle) scheduler.Pending = true;
}

pub fn detach(target: *Thread) SchedulingError!void {
    const previous_flags = guard.acquire();
    defer guard.release(previous_flags);
    const scheduler = state.getState();
    if (!scheduler.Initialized) return SchedulingError.NotInitialized;
    if (scheduler.IRQDepth != 0 or scheduler.PreemptionDepth != 0) return SchedulingError.UnsafeContext;
    if (!thread.state.owns(target)) return SchedulingError.InvalidThread;
    const record = registry.find(target) orelse return SchedulingError.NotManaged;
    if (!target.Managed) return SchedulingError.InvalidState;
    if (target == thread.state.getCurrent() or target.Permanent or record == scheduler.Idle) return SchedulingError.InUse;
    if (target.Status != .Ready and target.Status != .Blocked) return SchedulingError.InvalidState;
    if (record.Queue) |owner| {
        if (!queue.remove(owner, record)) @panic(messages.INVALID_QUEUE);
    }
    target.Status = .Stopped;
    thread.state.notifyInactive(target);
    target.Managed = false;
    if (!registry.release(record)) @panic(messages.INVALID_STATE);
}
