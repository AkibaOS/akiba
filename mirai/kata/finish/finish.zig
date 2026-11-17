//! Whole Kata Terminal Execution

const collect = @import("mirai").kata.collect;
const errors = @import("mirai").kata.errors.ownership;
const guard = @import("asm").interrupts.guard;
const lifecycle = @import("mirai").kata.lifecycle;
const messages = @import("mirai").kata.strings.messages;
const sensei = @import("mirai").sensei;
const state = @import("mirai").kata.state;
const thread = @import("mirai").thread;
const types = @import("mirai").kata.types;

const Fault = types.fault.Fault;
const Kata = types.kata.Kata;
const Outcome = types.outcome.Outcome;
const OwnershipError = errors.OwnershipError;
const Thread = thread.types.thread.Thread;

pub fn normal() noreturn {
    finishCurrent(.Completed);
}

pub fn complete(code: u64) noreturn {
    finishCurrent(.{ .Exited = code });
}

pub fn fault(details: Fault) noreturn {
    finishCurrent(.{ .Faulted = details });
}

fn safeContext() bool {
    const scheduler = sensei.state.getState();
    return scheduler.Initialized and scheduler.IRQDepth == 0 and scheduler.PreemptionDepth == 0;
}

fn stopThreads(owner: *Kata, excluding: ?*Thread) void {
    var current = thread.state.firstFor(owner);
    while (current) |target| {
        current = thread.state.nextFor(target);
        if (target == excluding) continue;
        if (target.Managed) {
            if (target.Status == .Stopped) continue;
            sensei.control.detach(target) catch @panic(messages.INVALID_COMPLETION);
        } else {
            if (target.Permanent or (target.Status != .Ready and target.Status != .Stopped))
                @panic(messages.INVALID_COMPLETION);
            if (target.Status != .Stopped) thread.execution.change(target, .Stopped);
            thread.state.notifyInactive(target);
        }
    }
}

pub fn terminate(owner: *Kata, outcome: Outcome) OwnershipError!void {
    const previous_flags = guard.acquire();
    defer guard.release(previous_flags);
    if (!safeContext()) return OwnershipError.InvalidState;
    const current = thread.state.getCurrent() orelse return OwnershipError.InvalidState;
    if (!state.owns(owner)) return OwnershipError.InvalidKata;
    if (owner.Permanent or current.Owner == owner) return OwnershipError.InUse;
    if (owner.State != .Alive and owner.State != .Sleeping) return OwnershipError.InvalidState;
    lifecycle.die(owner, outcome);
    stopThreads(owner, null);
    collect.collect();
}

fn finishCurrent(outcome: Outcome) noreturn {
    _ = guard.acquire();
    const current = thread.state.getCurrent() orelse @panic(messages.INVALID_COMPLETION);
    if (!safeContext() or !thread.state.owns(current) or !current.Managed or current.Permanent or
        current.Status != .Running) @panic(messages.INVALID_COMPLETION);
    const owner = current.Owner;
    if (!state.owns(owner) or owner.Permanent or owner.State != .Alive) @panic(messages.INVALID_COMPLETION);
    lifecycle.die(owner, outcome);
    stopThreads(owner, current);
    sensei.run.stopCurrent();
}
