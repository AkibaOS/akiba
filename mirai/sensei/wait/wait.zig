//! Atomic Condition Waiting And Wakeup

const errors = @import("mirai").sensei.errors.scheduling;
const guard = @import("asm").interrupts.guard;
const messages = @import("mirai").sensei.strings.messages;
const queue = @import("mirai").sensei.queue;
const registry = @import("mirai").sensei.registry;
const run = @import("mirai").sensei.run;
const state = @import("mirai").sensei.state;
const thread = @import("mirai").thread;
const types = @import("mirai").sensei.types;

const Predicate = types.predicate.Predicate;
const Queue = types.queue.Queue;
const Record = types.record.Record;
const SchedulingError = errors.SchedulingError;
const Thread = thread.types.thread.Thread;

pub fn blockUntil(waiters: *Queue, predicate: Predicate, context: ?*anyopaque) SchedulingError!void {
    const previous_flags = guard.acquire();
    defer guard.release(previous_flags);
    const scheduler = state.getState();
    if (!scheduler.Initialized) return SchedulingError.NotInitialized;
    if (!run.canCall(previous_flags)) return SchedulingError.UnsafeContext;
    if (waiters == &scheduler.Ready) return SchedulingError.InvalidQueue;
    const current = registry.current() orelse return SchedulingError.InvalidState;
    if (current == scheduler.Idle) return SchedulingError.InUse;
    while (!predicate(context)) {
        if (!queue.append(waiters, current)) @panic(messages.INVALID_QUEUE);
        run.reschedule(true);
        if (registry.current() != current or current.Queue != null) @panic(messages.INVALID_STATE);
    }
}

fn makeReady(record: *Record) void {
    const scheduler = state.getState();
    const target = record.Thread orelse @panic(messages.INVALID_STATE);
    if (!target.Managed or target.Status != .Blocked or record.Queue != null) @panic(messages.INVALID_STATE);
    target.Status = .Ready;
    if (!queue.append(&scheduler.Ready, record)) @panic(messages.INVALID_QUEUE);
    if (registry.current() == scheduler.Idle) scheduler.Pending = true;
}

pub fn wakeOne(waiters: *Queue) SchedulingError!bool {
    const previous_flags = guard.acquire();
    defer guard.release(previous_flags);
    const scheduler = state.getState();
    if (!scheduler.Initialized) return SchedulingError.NotInitialized;
    if (waiters == &scheduler.Ready) return SchedulingError.InvalidQueue;
    const record = queue.take(waiters) orelse return false;
    makeReady(record);
    return true;
}

pub fn wakeAll(waiters: *Queue) SchedulingError!u16 {
    const previous_flags = guard.acquire();
    defer guard.release(previous_flags);
    const scheduler = state.getState();
    if (!scheduler.Initialized) return SchedulingError.NotInitialized;
    if (waiters == &scheduler.Ready) return SchedulingError.InvalidQueue;
    var count: u16 = 0;
    while (queue.take(waiters)) |record| {
        makeReady(record);
        count += 1;
    }
    return count;
}

pub fn wake(target: *Thread) SchedulingError!bool {
    const previous_flags = guard.acquire();
    defer guard.release(previous_flags);
    const scheduler = state.getState();
    if (!scheduler.Initialized) return SchedulingError.NotInitialized;
    if (!thread.state.owns(target)) return SchedulingError.InvalidThread;
    const record = registry.find(target) orelse return SchedulingError.NotManaged;
    if (target.Status != .Blocked) return false;
    const waiters = record.Queue orelse return SchedulingError.InvalidState;
    if (waiters == &scheduler.Ready or !queue.remove(waiters, record)) @panic(messages.INVALID_QUEUE);
    makeReady(record);
    return true;
}
