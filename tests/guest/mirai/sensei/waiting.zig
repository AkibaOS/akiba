//! Predicate Wait And Cooperative Yield Regressions

const std = @import("std");

const guard = @import("asm").interrupts.guard;
const inputs = @import("tests").constants.sensei;
const kata = @import("mirai").kata;
const labels = @import("tests").strings.sensei;
const sensei = @import("mirai").sensei;
const support = @import("tests").guest.mirai.sensei.support;
const thread = @import("mirai").thread;
const types = @import("tests").types.sensei;
const verify = @import("tests").verify;

const Thread = thread.types.thread.Thread;
const WaitArgument = types.WaitArgument;
const WaitState = types.WaitState;

fn immediate(argument: ?*anyopaque) bool {
    const context: *WaitArgument = @ptrCast(@alignCast(argument.?));
    context.State.ImmediateChecks[context.Index] += 1;
    return true;
}

fn ready(argument: ?*anyopaque) bool {
    const context: *WaitArgument = @ptrCast(@alignCast(argument.?));
    context.State.Checks[context.Index] += 1;
    return context.State.Open;
}

fn entry(argument: ?*anyopaque) callconv(.{ .x86_64_sysv = .{} }) noreturn {
    const context: *WaitArgument = @ptrCast(@alignCast(argument.?));
    sensei.wait.blockUntil(&context.State.Immediate, immediate, argument) catch |failure| verify.failure(failure);
    const flags = guard.acquire();
    context.State.ImmediateReturned[context.Index] = true;
    context.State.YieldHadPeer[context.Index] = sensei.state.getState().Ready.Count != 0;
    guard.release(flags);
    sensei.run.yield() catch |failure| verify.failure(failure);
    const resumed_flags = guard.acquire();
    const current = thread.state.getCurrent().?;
    context.State.YieldReturned[context.Index] = current.Managed and current.Status == .Running and
        sensei.registry.current().?.Queue == null;
    guard.release(resumed_flags);
    sensei.wait.blockUntil(&context.State.Waiters, ready, argument) catch |failure| verify.failure(failure);
    _ = guard.acquire();
    context.State.Finished[context.Index] = true;
    thread.finish.complete();
}

pub fn run() !void {
    const owner = try kata.create.create();
    const owner_id = owner.ID;
    defer support.dispose(owner_id) catch |failure| verify.failure(failure);
    var state: WaitState = .{};
    var arguments: [inputs.WAITER_COUNT]WaitArgument = undefined;
    var targets: [inputs.WAITER_COUNT]*Thread = undefined;
    for (&arguments, &targets, 0..) |*argument, *target, index| {
        argument.* = .{ .State = &state, .Index = index };
        target.* = try thread.create.create(owner, entry, argument);
    }
    var registered: usize = 0;
    {
        const flags = guard.acquire();
        defer guard.release(flags);
        registered = sensei.state.getState().RegisteredCount;
        for (targets) |target| try sensei.control.start(target);
    }
    try support.drain(owner_id);
    var oldest: *Thread = undefined;
    var newest: *Thread = undefined;
    var oldest_index: usize = 0;
    {
        const flags = guard.acquire();
        defer guard.release(flags);
        verify.require(std.mem.allEqual(bool, &state.ImmediateReturned, true) and
            state.ImmediateChecks[0] == 1 and state.ImmediateChecks[1] == 1 and
            state.Immediate.Count == 0 and state.Immediate.Head == null and state.Immediate.Tail == null, labels.WAIT_IMMEDIATE);
        verify.require(std.mem.allEqual(bool, &state.YieldReturned, true) and
            (state.YieldHadPeer[0] or state.YieldHadPeer[1]), labels.WAIT_YIELD);
        verify.require(state.Waiters.Count == inputs.WAITER_COUNT and targets[0].Status == .Blocked and targets[1].Status == .Blocked and
            state.Checks[0] != 0 and state.Checks[1] != 0 and std.mem.allEqual(bool, &state.Finished, false), labels.WAIT_BLOCK);
        oldest = state.Waiters.Head.?.Thread.?;
        newest = state.Waiters.Tail.?.Thread.?;
        oldest_index = if (oldest == targets[0]) 0 else 1;
        const awakened = try sensei.wait.wakeOldest(&state.Waiters);
        verify.require(awakened == oldest and oldest != newest and oldest.Status == .Ready and newest.Status == .Blocked and
            state.Waiters.Count == 1 and state.Waiters.Head.?.Thread == newest and
            !(try sensei.wait.wake(oldest)), labels.WAIT_OLDEST);
    }
    try support.drain(owner_id);
    {
        const flags = guard.acquire();
        defer guard.release(flags);
        verify.require(state.Checks[oldest_index] >= 2 and state.Waiters.Count == inputs.WAITER_COUNT and
            state.Waiters.Head.?.Thread == newest and state.Waiters.Tail.?.Thread == oldest and
            oldest.Status == .Blocked and std.mem.allEqual(bool, &state.Finished, false), labels.WAIT_RECHECK);
        const awakened = try sensei.wait.wakeAll(&state.Waiters);
        verify.require(awakened == inputs.WAITER_COUNT and state.Waiters.Count == 0 and
            state.Waiters.Head == null and state.Waiters.Tail == null and
            targets[0].Status == .Ready and targets[1].Status == .Ready, labels.WAIT_ALL);
    }
    try support.drain(owner_id);
    var released: usize = 0;
    {
        const flags = guard.acquire();
        defer guard.release(flags);
        verify.require(state.Waiters.Count == inputs.WAITER_COUNT and state.Checks[0] >= 2 and state.Checks[1] >= 2 and
            targets[0].Status == .Blocked and targets[1].Status == .Blocked and
            std.mem.allEqual(bool, &state.Finished, false), labels.WAIT_REBLOCK);
        state.Open = true;
        released = try sensei.wait.wakeAll(&state.Waiters);
    }
    try support.drain(owner_id);
    const flags = guard.acquire();
    defer guard.release(flags);
    verify.require(released == inputs.WAITER_COUNT and std.mem.allEqual(bool, &state.Finished, true) and
        state.Waiters.Count == 0 and state.Waiters.Head == null and state.Waiters.Tail == null and
        kata.state.findByID(owner_id) == null, labels.WAIT_COMPLETE);
    try support.dispose(owner_id);
    verify.require((try sensei.wait.wakeAll(&state.Waiters)) == 0 and !(try sensei.wait.wakeOne(&state.Waiters)) and
        (try sensei.wait.wakeOldest(&state.Waiters)) == null and kata.completion.storage.ownerOf(owner_id) == null and
        sensei.state.getState().RegisteredCount == registered, labels.WAIT_RELEASE);
}
