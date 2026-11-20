//! Open Completion Waiting And Registration Cleanup

const checks = if (options.GUEST_CHECKS) @import("tests").guest.mirai.kata.race else null;
const completion = @import("mirai").kata.completion;
const control = @import("asm").cpu.constants.control.registers;
const errors = @import("mirai").kata.errors.completion;
const guard = @import("asm").interrupts.guard;
const messages = @import("mirai").kata.strings.messages;
const options = @import("options");
const scheduling = @import("mirai").sensei.errors.scheduling;
const sensei = @import("mirai").sensei;
const state = @import("mirai").kata.state;
const thread = @import("mirai").thread;
const types = @import("mirai").kata.types;

const CompletionError = errors.CompletionError;
const Observer = types.observer.Observer;
const Outcome = types.outcome.Outcome;
const Registration = types.wait.Registration;
const SchedulingError = scheduling.SchedulingError;
const Thread = thread.types.thread.Thread;

fn find(target: *const Thread) ?*Observer {
    const slot = thread.state.data(target) orelse return null;
    const observer = &slot.Observer;
    return if (observer.Thread == target and observer.OwnerID == target.Owner.ID) observer else null;
}

fn available(target: *const Thread) ?*Observer {
    const slot = thread.state.data(target) orelse return null;
    return if (slot.Observer.Thread == null) &slot.Observer else null;
}

fn ready(context: ?*anyopaque) bool {
    const observer: *const Observer = @ptrCast(@alignCast(context orelse @panic(messages.INVALID_OBSERVER)));
    return completion.lifetime.observed(observer.TargetID) != null;
}

fn unregister(observer: *Observer) void {
    completion.lifetime.drop(observer.TargetID);
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

fn register(current: *Thread, id: u64) CompletionError!Registration {
    if (!thread.state.owns(current) or current.Permanent or !current.Managed or current.Status != .Running or
        !state.owns(current.Owner) or current.Owner.State != .Alive or find(current) != null) return CompletionError.InvalidCaller;
    if (id == current.Owner.ID) return CompletionError.InvalidTarget;
    const observer = available(current) orelse return CompletionError.ObserverCapacity;
    const record = try completion.lifetime.borrow(id);
    observer.* = .{ .Thread = current, .OwnerID = current.Owner.ID, .TargetID = id };
    return .{ .Observer = observer, .Completion = record, .Thread = current };
}

fn observed(registration: Registration) Outcome {
    const observer = registration.Observer;
    if (thread.state.getCurrent() != registration.Thread or observer.Thread != registration.Thread or
        observer.OwnerID != registration.Thread.Owner.ID) @panic(messages.INVALID_OBSERVER);
    return completion.lifetime.observed(observer.TargetID) orelse @panic(messages.INVALID_OBSERVER);
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
    const registration = register(current, id) catch |failure| {
        guard.release(previous_flags);
        return failure;
    };
    guard.release(previous_flags);
    if (options.GUEST_CHECKS) checks.registered(id);
    sensei.wait.blockUntil(&registration.Completion.Waiters, ready, @ptrCast(registration.Observer)) catch |failure| {
        const flags = guard.acquire();
        defer guard.release(flags);
        unregister(registration.Observer);
        return failure;
    };
    const flags = guard.acquire();
    defer guard.release(flags);
    const outcome = observed(registration);
    unregister(registration.Observer);
    return outcome;
}

pub fn waitFromInvocation(id: u64) (CompletionError || SchedulingError)!Outcome {
    const previous_flags = guard.acquire();
    defer guard.release(previous_flags);
    const scheduler = sensei.state.getState();
    if (!scheduler.Initialized) return SchedulingError.NotInitialized;
    if ((previous_flags & control.RFLAGS_INTERRUPT_ENABLE) != 0 or scheduler.IRQDepth != 0 or
        scheduler.PreemptionDepth != 0) return SchedulingError.UnsafeContext;
    const current = thread.state.getCurrent() orelse return CompletionError.InvalidCaller;
    if (current.Mode != .Persona) return CompletionError.InvalidCaller;
    const registration = try register(current, id);
    errdefer unregister(registration.Observer);
    if (options.GUEST_CHECKS) checks.registered(id);
    try sensei.wait.blockFromInvocation(&registration.Completion.Waiters, ready, @ptrCast(registration.Observer), null);
    return observed(registration);
}

pub fn releaseFromInvocation(id: u64) void {
    const flags = guard.acquire();
    defer guard.release(flags);
    const current = thread.state.getCurrent() orelse @panic(messages.INVALID_OBSERVER);
    const observer = find(current) orelse @panic(messages.INVALID_OBSERVER);
    if (current.Mode != .Persona or observer.TargetID != id) @panic(messages.INVALID_OBSERVER);
    unregister(observer);
}
