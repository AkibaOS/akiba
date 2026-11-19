//! Kata Completion Retention And Adoption Regressions

const std = @import("std");

const budget = @import("tests").guest.support.allocation;
const guard = @import("asm").interrupts.guard;
const inputs = @import("tests").guest.constants.retention;
const kata = @import("mirai").kata;
const labels = @import("tests").strings.retention;
const limits = @import("tests").guest.constants.guest;
const pmm = @import("mirai").pmm;
const pool = @import("mirai").kata.constants.pool;
const sensei = @import("mirai").sensei;
const support = @import("tests").guest.mirai.sensei.support;
const thread = @import("mirai").thread;
const types = @import("tests").guest.types.retention;
const verify = @import("tests").guest.support.verify;

const Kata = kata.types.kata.Kata;
const Outcome = kata.types.outcome.Outcome;
const WaitArgument = types.WaitArgument;
const WaitFixture = types.WaitFixture;

var retained_ids = [_]u64{pool.KERNEL_ID} ** inputs.RETAINED_COUNT;

pub fn run() !void {
    const current = thread.state.getCurrent();
    const kernel = kata.state.getKernel();
    const flags = guard.acquire();
    const callable = sensei.run.canCall(flags);
    guard.release(flags);
    verify.require(callable and current != null and kernel != null and current.?.Owner == kernel.? and
        current.?.Status == .Running and kernel.?.State == .Alive, labels.CALLER);
    try waits();
    try @call(.never_inline, capacity, .{});
    try adoption();
}

fn finish(_: ?*anyopaque) callconv(.{ .x86_64_sysv = .{} }) noreturn {
    thread.finish.complete();
}

fn never(_: ?*anyopaque) bool {
    return false;
}

fn parked(argument: ?*anyopaque) callconv(.{ .x86_64_sysv = .{} }) noreturn {
    const fixture: *WaitFixture = @ptrCast(@alignCast(argument.?));
    sensei.wait.blockUntil(&fixture.Parked, never, null) catch |failure| verify.failure(failure);
    @panic(labels.UNEXPECTED_RESUME);
}

fn rejectedWait(id: u64) bool {
    if (kata.wait.waitFor(id)) |_| {
        return false;
    } else |failure| {
        return failure == error.InvalidTarget;
    }
}

fn observe(argument: ?*anyopaque) callconv(.{ .x86_64_sysv = .{} }) noreturn {
    const context: *WaitArgument = @ptrCast(@alignCast(argument.?));
    const fixture = context.Fixture;
    const result = &fixture.Results[context.Index];
    result.Invalid = rejectedWait(inputs.INVALID_ID);
    result.Born = rejectedWait(fixture.BornID);
    result.Self = rejectedWait(thread.state.getCurrent().?.Owner.ID);
    result.Reclaimed = kata.wait.waitFor(fixture.ReclaimedID) catch |failure| verify.failure(failure);
    result.Final = kata.wait.waitFor(fixture.TargetID) catch |failure| verify.failure(failure);
    thread.finish.complete();
}

fn matches(outcome: ?Outcome, value: u64) bool {
    const copied = outcome orelse return false;
    return copied == .Exited and copied.Exited == value;
}

fn admitted(launcher: *const Kata) !*Kata {
    const flags = guard.acquire();
    defer guard.release(flags);
    const owner = try kata.create.createFor(launcher);
    const id = owner.ID;
    errdefer support.dispose(id) catch |failure| verify.failure(failure);
    try sensei.control.start(try thread.create.create(owner, finish, null));
    return owner;
}

fn retained(launcher: *const Kata, value: u64) !u64 {
    const flags = guard.acquire();
    defer guard.release(flags);
    const owner = try admitted(launcher);
    const id = owner.ID;
    errdefer support.dispose(id) catch |failure| verify.failure(failure);
    try kata.finish.terminate(owner, .{ .Exited = value });
    return id;
}

fn drain(owners: []const u64) !void {
    var attempts: usize = 0;
    while (attempts < limits.DRIVE_LIMIT) : (attempts += 1) {
        try sensei.run.yield();
        const flags = guard.acquire();
        const runnable = sensei.state.getState().Ready.Count != 0;
        guard.release(flags);
        if (!runnable) return;
    }
    const flags = guard.acquire();
    defer guard.release(flags);
    for (owners) |id| try support.dispose(id);
    verify.require(false, labels.DRIVE_LIMIT);
}

fn waits() !void {
    const born = try kata.create.create();
    const born_id = born.ID;
    defer support.dispose(born_id) catch |failure| verify.failure(failure);
    const reclaimed_id = try retained(kata.state.getKernel().?, inputs.RECLAIMED_RESULT);
    defer support.dispose(reclaimed_id) catch |failure| verify.failure(failure);
    const target = try kata.create.create();
    const target_id = target.ID;
    defer support.dispose(target_id) catch |failure| verify.failure(failure);
    var fixture: WaitFixture = .{ .BornID = born_id, .ReclaimedID = reclaimed_id, .TargetID = target_id };
    const target_thread = try thread.create.create(target, parked, &fixture);
    const watcher = try kata.create.create();
    const watcher_id = watcher.ID;
    defer support.dispose(watcher_id) catch |failure| verify.failure(failure);
    var arguments: [inputs.OBSERVER_COUNT]WaitArgument = undefined;
    var watchers: [inputs.OBSERVER_COUNT]*thread.types.thread.Thread = undefined;
    for (&arguments, &watchers, 0..) |*argument, *watcher_thread, index| {
        argument.* = .{ .Fixture = &fixture, .Index = index };
        watcher_thread.* = try thread.create.create(watcher, observe, argument);
    }
    const owners = [_]u64{ watcher_id, target_id, reclaimed_id, born_id };
    {
        const flags = guard.acquire();
        defer guard.release(flags);
        try sensei.control.start(target_thread);
        for (watchers) |watcher_thread| try sensei.control.start(watcher_thread);
    }
    try drain(&owners);
    {
        const flags = guard.acquire();
        defer guard.release(flags);
        verify.require(fixture.Results[0].Invalid and fixture.Results[1].Invalid, labels.WAIT_INVALID);
        verify.require(fixture.Results[0].Born and fixture.Results[1].Born and born.State == .Born, labels.WAIT_BORN);
        verify.require(fixture.Results[0].Self and fixture.Results[1].Self, labels.WAIT_SELF);
        const reclaimed = try kata.completion.lifetime.borrow(reclaimed_id);
        const immediate = reclaimed.Observers == 1 and reclaimed.Waiters.Count == 0 and reclaimed.Reclaimed;
        kata.completion.lifetime.drop(reclaimed_id);
        verify.require(immediate and matches(fixture.Results[0].Reclaimed, inputs.RECLAIMED_RESULT) and
            matches(fixture.Results[1].Reclaimed, inputs.RECLAIMED_RESULT), labels.WAIT_RECLAIMED);
        const record = try kata.completion.lifetime.borrow(target_id);
        kata.completion.lifetime.drop(target_id);
        verify.require(record.Observers == inputs.OBSERVER_COUNT and record.Waiters.Count == inputs.OBSERVER_COUNT and
            fixture.Parked.Count == 1 and watcher.State == .Sleeping and record.Outcome == null, labels.OBSERVERS);
        try kata.finish.terminate(target, .{ .Exited = inputs.TARGET_RESULT });
        verify.require(!kata.completion.lifetime.commit(target_id, .Completed) and
            matches(record.Outcome, inputs.TARGET_RESULT) and matches(kata.completion.lifetime.peek(target_id), inputs.TARGET_RESULT), labels.IMMUTABLE);
        const collected = try kata.completion.lifetime.collect(target_id);
        verify.require(matches(collected, inputs.TARGET_RESULT) and record.Collected and record.Reclaimed and
            record.Observers == inputs.OBSERVER_COUNT and record.Waiters.Count == 0 and
            kata.completion.lifetime.peek(target_id) == null and kata.completion.storage.ownerOf(target_id) != null and
            matches(kata.completion.lifetime.observed(target_id), inputs.TARGET_RESULT), labels.COLLECT_RETAINED);
    }
    try drain(&owners);
    const flags = guard.acquire();
    defer guard.release(flags);
    for (owners) |id| try support.dispose(id);
    verify.require(matches(fixture.Results[0].Final, inputs.TARGET_RESULT) and matches(fixture.Results[1].Final, inputs.TARGET_RESULT) and
        kata.completion.storage.ownerOf(target_id) == null and kata.completion.storage.ownerOf(watcher_id) == null and
        kata.completion.storage.ownerOf(reclaimed_id) == null and kata.completion.storage.ownerOf(born_id) == null and
        kata.state.findByID(watcher_id) == null and fixture.Parked.Count == 0 and
        fixture.Parked.Head == null and fixture.Parked.Tail == null, labels.OBSERVERS_RELEASE);
}

fn capacity() !void {
    const flags = guard.acquire();
    defer guard.release(flags);
    defer budget.clear();
    const kernel = kata.state.getKernel().?;
    const warm_id = try retained(kernel, inputs.RECLAIMED_RESULT);
    try support.dispose(warm_id);
    const warm = pmm.state.getStatistics();
    var count: usize = 0;
    var borrowed: usize = 0;
    defer {
        budget.clear();
        while (borrowed != 0) {
            kata.completion.lifetime.drop(retained_ids[0]);
            borrowed -= 1;
        }
        while (count != 0) {
            count -= 1;
            support.dispose(retained_ids[count]) catch |failure| verify.failure(failure);
            retained_ids[count] = pool.KERNEL_ID;
        }
    }
    while (count < retained_ids.len) {
        const id = try retained(kernel, inputs.RECLAIMED_RESULT + count);
        retained_ids[count] = id;
        count += 1;
        sensei.retire.collect();
        kata.collect.collect();
    }
    var retained_results = true;
    for (retained_ids, 0..) |id, index| {
        retained_results = retained_results and kata.state.findByID(id) == null and
            kata.completion.storage.ownerOf(id) == kernel.ID and matches(kata.completion.lifetime.peek(id), inputs.RECLAIMED_RESULT + index);
    }
    verify.require(retained_results and count == inputs.RETAINED_COUNT and kata.state.canReserve(), labels.CAPACITY);
    var record: ?*kata.types.completion.Completion = null;
    while (borrowed < inputs.RETAINED_COUNT) : (borrowed += 1) record = try kata.completion.lifetime.borrow(retained_ids[0]);
    const held = record.?.Observers;
    record.?.Observers = std.math.maxInt(usize);
    var overflow = false;
    if (kata.completion.lifetime.borrow(retained_ids[0])) |_| {
        overflow = false;
    } else |failure| {
        overflow = failure == error.ObserverCapacity;
    }
    const preserved = record.?.Observers == std.math.maxInt(usize);
    record.?.Observers = held;
    verify.require(held == inputs.RETAINED_COUNT and record.?.Waiters.Count == 0 and overflow and preserved, labels.CAPACITY_OBSERVERS);
    budget.arm(0);
    var collected = true;
    for (retained_ids, 0..) |id, index| {
        const outcome = try kata.completion.lifetime.collect(id);
        collected = collected and matches(outcome, inputs.RECLAIMED_RESULT + index);
    }
    collected = collected and record.?.Collected and record.?.Observers == inputs.RETAINED_COUNT;
    while (borrowed != 0) {
        kata.completion.lifetime.drop(retained_ids[0]);
        borrowed -= 1;
    }
    budget.clear();
    for (retained_ids) |id| collected = collected and kata.completion.storage.ownerOf(id) == null;
    verify.require(collected and std.meta.eql(warm, pmm.state.getStatistics()), labels.CAPACITY_UNWIND);
    const before = pmm.state.getStatistics();
    var rejected = false;
    budget.arm(1);
    if (kata.create.createFor(kernel)) |unexpected| {
        budget.clear();
        try kata.destroy.destroy(unexpected);
    } else |failure| {
        budget.clear();
        rejected = failure == error.OutOfMemory;
    }
    const restored = std.meta.eql(before, pmm.state.getStatistics());
    const replacement = try kata.create.createFor(kernel);
    try kata.destroy.destroy(replacement);
    verify.require(rejected and restored and kata.state.canReserve() and std.meta.eql(before, pmm.state.getStatistics()), labels.CAPACITY_RECOVERY);
}

fn adoption() !void {
    const flags = guard.acquire();
    defer guard.release(flags);
    const kernel = kata.state.getKernel().?;
    const probe = try kata.create.createFor(kernel);
    const probe_id = probe.ID;
    defer support.dispose(probe_id) catch |failure| verify.failure(failure);
    const available = kata.lifecycle.designatePulse(probe);
    try kata.destroy.destroy(probe);
    if (!available) {
        verify.require(false, labels.PULSE_AVAILABLE);
        return;
    }
    var family = [_]u64{pool.KERNEL_ID} ** inputs.FAMILY_COUNT;
    defer {
        for (family) |id| {
            if (id != pool.KERNEL_ID) support.dispose(id) catch |failure| verify.failure(failure);
        }
    }
    const parent = try admitted(kernel);
    const parent_id = parent.ID;
    family[0] = parent_id;
    const live = try admitted(parent);
    const live_id = live.ID;
    family[1] = live_id;
    const retained_id = try retained(parent, inputs.RECLAIMED_RESULT);
    family[2] = retained_id;
    try kata.finish.terminate(parent, .Completed);
    try support.dispose(parent_id);
    verify.require(kata.completion.storage.ownerOf(live_id) == kernel.ID and kata.completion.storage.ownerOf(retained_id) == kernel.ID and
        live.State == .Alive and kata.state.findByID(retained_id) == null and
        matches(kata.completion.lifetime.peek(retained_id), inputs.RECLAIMED_RESULT), labels.ADOPTION_KERNEL);
    const pulse = try kata.create.createFor(kernel);
    const pulse_id = pulse.ID;
    defer support.dispose(pulse_id) catch |failure| verify.failure(failure);
    const designated = kata.lifecycle.designatePulse(pulse);
    const adopted = designated and pulse.State == .Born and kata.completion.storage.ownerOf(live_id) == pulse_id and
        kata.completion.storage.ownerOf(retained_id) == pulse_id and kata.completion.storage.ownerOf(pulse_id) == kernel.ID;
    try kata.destroy.destroy(pulse);
    const restored = kata.completion.storage.ownerOf(live_id) == kernel.ID and kata.completion.storage.ownerOf(retained_id) == kernel.ID and
        kata.completion.storage.ownerOf(pulse_id) == null and live.State == .Alive and
        matches(kata.completion.lifetime.peek(retained_id), inputs.RECLAIMED_RESULT);
    const recovery = try kata.create.createFor(kernel);
    const recovery_id = recovery.ID;
    defer support.dispose(recovery_id) catch |failure| verify.failure(failure);
    const redesignated = kata.lifecycle.designatePulse(recovery);
    try kata.destroy.destroy(recovery);
    verify.require(adopted, labels.ADOPTION_PULSE);
    verify.require(restored and redesignated and kata.completion.storage.ownerOf(live_id) == kernel.ID and
        kata.completion.storage.ownerOf(retained_id) == kernel.ID and kata.completion.storage.ownerOf(recovery_id) == null, labels.ADOPTION_ROLLBACK);
    try kata.finish.terminate(live, .{ .Exited = inputs.ADOPTED_RESULT });
    const live_result = try kata.completion.lifetime.collect(live_id);
    const retained_result = try kata.completion.lifetime.collect(retained_id);
    verify.require(matches(live_result, inputs.ADOPTED_RESULT) and matches(retained_result, inputs.RECLAIMED_RESULT) and
        kata.state.findByID(live_id) == null and kata.completion.storage.ownerOf(live_id) == null and
        kata.completion.storage.ownerOf(retained_id) == null and kata.completion.storage.ownerOf(parent_id) == null, labels.ADOPTION_RESULTS);
}
