//! Open Completion Waiting And Registration Cleanup

const completion = @import("mirai").kata.completion;
const errors = @import("mirai").kata.errors.completion;
const guard = @import("asm").interrupts.guard;
const limits = @import("mirai").thread.constants.pool;
const messages = @import("mirai").kata.strings.messages;
const scheduling = @import("mirai").sensei.errors.scheduling;
const sensei = @import("mirai").sensei;
const state = @import("mirai").kata.state;
const thread = @import("mirai").thread;
const types = @import("mirai").kata.types;

const CompletionError = errors.CompletionError;
const Observer = types.observer.Observer;
const Outcome = types.outcome.Outcome;
const SchedulingError = scheduling.SchedulingError;
const Thread = thread.types.thread.Thread;

var observers: [limits.MAX_THREADS]Observer = [_]Observer{.{}} ** limits.MAX_THREADS;

fn find(target: *const Thread) ?*Observer {
    for (&observers) |*observer| {
        if (observer.Thread == target and observer.OwnerID == target.Owner.ID) return observer;
    }
    return null;
}

fn available() ?*Observer {
    for (&observers) |*observer| {
        if (observer.Thread == null) return observer;
    }
    return null;
}

fn ready(context: ?*anyopaque) bool {
    const observer: *const Observer = @ptrCast(@alignCast(context orelse @panic(messages.INVALID_OBSERVER)));
    return completion.observed(observer.TargetID) != null;
}

fn unregister(observer: *Observer) void {
    completion.drop(observer.TargetID);
    observer.* = .{};
}

pub fn cancel(target: *Thread) void {
    const previous_flags = guard.acquire();
    defer guard.release(previous_flags);
    if (!thread.state.owns(target)) return;
    const observer = find(target) orelse return;
    if (sensei.registry.find(target)) |record| {
        if (record.Queue != null) @panic(messages.INVALID_OBSERVER);
    }
    unregister(observer);
}

pub fn waitFor(id: u64) (CompletionError || SchedulingError)!Outcome {
    const previous_flags = guard.acquire();
    if (!sensei.state.isInitialized()) {
        guard.release(previous_flags);
        return SchedulingError.NotInitialized;
    }
    if (!sensei.run.canCall(previous_flags)) {
        guard.release(previous_flags);
        return SchedulingError.UnsafeContext;
    }
    const current = thread.state.getCurrent() orelse {
        guard.release(previous_flags);
        return CompletionError.InvalidCaller;
    };
    if (!thread.state.owns(current) or current.Permanent or !current.Managed or current.Status != .Running or
        !state.owns(current.Owner) or current.Owner.State != .Alive or find(current) != null)
    {
        guard.release(previous_flags);
        return CompletionError.InvalidCaller;
    }
    if (id == current.Owner.ID) {
        guard.release(previous_flags);
        return CompletionError.InvalidTarget;
    }
    const observer = available() orelse {
        guard.release(previous_flags);
        return CompletionError.ObserverCapacity;
    };
    const record = completion.borrow(id) catch |failure| {
        guard.release(previous_flags);
        return failure;
    };
    observer.* = .{ .Thread = current, .OwnerID = current.Owner.ID, .TargetID = id };
    guard.release(previous_flags);
    sensei.wait.blockUntil(&record.Waiters, ready, @ptrCast(observer)) catch |failure| {
        const flags = guard.acquire();
        defer guard.release(flags);
        unregister(observer);
        return failure;
    };
    const flags = guard.acquire();
    defer guard.release(flags);
    if (observer.Thread != current or observer.OwnerID != current.Owner.ID) @panic(messages.INVALID_OBSERVER);
    const outcome = completion.observed(id) orelse @panic(messages.INVALID_OBSERVER);
    unregister(observer);
    return outcome;
}
