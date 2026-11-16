//! Kata Completion Retention And Adoption Regressions

const std = @import("std");

const guard = @import("asm").interrupts.guard;
const inputs = @import("tests").constants.retention;
const kata = @import("mirai").kata;
const labels = @import("tests").strings.retention;
const limits = @import("tests").constants.guest;
const pmm = @import("mirai").pmm;
const pool = @import("mirai").kata.constants.pool;
const sensei = @import("mirai").sensei;
const support = @import("tests").guest.mirai.sensei.support;
const thread = @import("mirai").thread;
const types = @import("tests").types.retention;
const verify = @import("tests").verify;

const Kata = kata.types.kata.Kata;
const Outcome = kata.types.outcome.Outcome;
const WaitArgument = types.WaitArgument;
const WaitFixture = types.WaitFixture;

pub fn run() !void {
    const current = thread.state.getCurrent();
    const kernel = kata.state.getKernel();
    const flags = guard.acquire();
    const callable = sensei.run.canCall(flags);
    guard.release(flags);
    verify.require(callable and current != null and kernel != null and current.?.Owner == kernel.? and
        current.?.Status == .Running and kernel.?.State == .Alive, labels.CALLER);
    try waits();
    try capacity();
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
        const reclaimed = try kata.completion.borrow(reclaimed_id);
        const immediate = reclaimed.Observers == 1 and reclaimed.Waiters.Count == 0 and reclaimed.Reclaimed;
        kata.completion.drop(reclaimed_id);
        verify.require(immediate and matches(fixture.Results[0].Reclaimed, inputs.RECLAIMED_RESULT) and
            matches(fixture.Results[1].Reclaimed, inputs.RECLAIMED_RESULT), labels.WAIT_RECLAIMED);
        const record = try kata.completion.borrow(target_id);
        kata.completion.drop(target_id);
        verify.require(record.Observers == inputs.OBSERVER_COUNT and record.Waiters.Count == inputs.OBSERVER_COUNT and
            fixture.Parked.Count == 1 and watcher.State == .Sleeping and record.Outcome == null, labels.OBSERVERS);
        try kata.finish.terminate(target, .{ .Exited = inputs.TARGET_RESULT });
        verify.require(!kata.completion.commit(target_id, .Completed) and
            matches(record.Outcome, inputs.TARGET_RESULT) and matches(kata.completion.peek(target_id), inputs.TARGET_RESULT), labels.IMMUTABLE);
        const collected = try kata.completion.collect(target_id);
        verify.require(matches(collected, inputs.TARGET_RESULT) and record.Collected and record.Reclaimed and
            record.Observers == inputs.OBSERVER_COUNT and record.Waiters.Count == 0 and
            kata.completion.peek(target_id) == null and kata.completion.ownerOf(target_id) != null and
            matches(kata.completion.observed(target_id), inputs.TARGET_RESULT), labels.COLLECT_RETAINED);
    }
    try drain(&owners);
    const flags = guard.acquire();
    defer guard.release(flags);
    for (owners) |id| try support.dispose(id);
    verify.require(matches(fixture.Results[0].Final, inputs.TARGET_RESULT) and matches(fixture.Results[1].Final, inputs.TARGET_RESULT) and
        kata.completion.ownerOf(target_id) == null and kata.completion.ownerOf(watcher_id) == null and
        kata.completion.ownerOf(reclaimed_id) == null and kata.completion.ownerOf(born_id) == null and
        kata.state.findByID(watcher_id) == null and fixture.Parked.Count == 0 and
        fixture.Parked.Head == null and fixture.Parked.Tail == null, labels.OBSERVERS_RELEASE);
}

fn capacity() !void {
    const flags = guard.acquire();
    defer guard.release(flags);
    const kernel = kata.state.getKernel().?;
    const retained_id = try retained(kernel, inputs.RECLAIMED_RESULT);
    defer support.dispose(retained_id) catch |failure| verify.failure(failure);
    const warm = pmm.state.getStatistics();
    var owners = [_]?*Kata{null} ** pool.MAX_KATAS;
    var count: usize = 0;
    defer {
        while (count != 0) {
            count -= 1;
            if (owners[count]) |owner| kata.destroy.destroy(owner) catch |failure| verify.failure(failure);
        }
    }
    while (count < owners.len and kata.completion.hasCapacity()) : (count += 1) {
        owners[count] = try kata.create.createFor(kernel);
    }
    const full = pmm.state.getStatistics();
    const search = pmm.state.getState().SearchStart;
    var rejected = false;
    if (kata.create.createFor(kernel)) |unexpected| {
        try kata.destroy.destroy(unexpected);
    } else |failure| {
        rejected = failure == error.OutOfMemory;
    }
    const refused = rejected and count != 0 and count < pool.MAX_KATAS and
        !kata.completion.hasCapacity() and !kata.state.canReserve() and
        full.FreePages + count == warm.FreePages and full.UsedPages == warm.UsedPages + count and
        pmm.state.getState().SearchStart == search and std.meta.eql(full, pmm.state.getStatistics());
    var recovered = false;
    if (count != 0) {
        const previous = owners[count - 1].?;
        const previous_id = previous.ID;
        try kata.destroy.destroy(previous);
        owners[count - 1] = null;
        const reopened = kata.completion.hasCapacity() and kata.state.canReserve() and
            pmm.state.getStatistics().FreePages == full.FreePages + 1;
        const replacement = try kata.create.createFor(kernel);
        owners[count - 1] = replacement;
        recovered = reopened and replacement == previous and replacement.ID > previous_id and
            !kata.completion.hasCapacity() and std.meta.eql(full, pmm.state.getStatistics());
    }
    while (count != 0) {
        const index = count - 1;
        if (owners[index]) |owner| try kata.destroy.destroy(owner);
        owners[index] = null;
        count -= 1;
    }
    try support.dispose(retained_id);
    const unwound = std.meta.eql(warm, pmm.state.getStatistics()) and kata.completion.hasCapacity() and
        kata.completion.ownerOf(retained_id) == null;
    verify.require(refused, labels.CAPACITY);
    verify.require(recovered, labels.CAPACITY_RECOVERY);
    verify.require(unwound, labels.CAPACITY_UNWIND);
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
    verify.require(kata.completion.ownerOf(live_id) == kernel.ID and kata.completion.ownerOf(retained_id) == kernel.ID and
        live.State == .Alive and kata.state.findByID(retained_id) == null and
        matches(kata.completion.peek(retained_id), inputs.RECLAIMED_RESULT), labels.ADOPTION_KERNEL);
    const pulse = try kata.create.createFor(kernel);
    const pulse_id = pulse.ID;
    defer support.dispose(pulse_id) catch |failure| verify.failure(failure);
    const designated = kata.lifecycle.designatePulse(pulse);
    const adopted = designated and pulse.State == .Born and kata.completion.ownerOf(live_id) == pulse_id and
        kata.completion.ownerOf(retained_id) == pulse_id and kata.completion.ownerOf(pulse_id) == kernel.ID;
    try kata.destroy.destroy(pulse);
    const restored = kata.completion.ownerOf(live_id) == kernel.ID and kata.completion.ownerOf(retained_id) == kernel.ID and
        kata.completion.ownerOf(pulse_id) == null and live.State == .Alive and
        matches(kata.completion.peek(retained_id), inputs.RECLAIMED_RESULT);
    const recovery = try kata.create.createFor(kernel);
    const recovery_id = recovery.ID;
    defer support.dispose(recovery_id) catch |failure| verify.failure(failure);
    const redesignated = kata.lifecycle.designatePulse(recovery);
    try kata.destroy.destroy(recovery);
    verify.require(adopted, labels.ADOPTION_PULSE);
    verify.require(restored and redesignated and kata.completion.ownerOf(live_id) == kernel.ID and
        kata.completion.ownerOf(retained_id) == kernel.ID and kata.completion.ownerOf(recovery_id) == null, labels.ADOPTION_ROLLBACK);
    try kata.finish.terminate(live, .{ .Exited = inputs.ADOPTED_RESULT });
    const live_result = try kata.completion.collect(live_id);
    const retained_result = try kata.completion.collect(retained_id);
    verify.require(matches(live_result, inputs.ADOPTED_RESULT) and matches(retained_result, inputs.RECLAIMED_RESULT) and
        kata.state.findByID(live_id) == null and kata.completion.ownerOf(live_id) == null and
        kata.completion.ownerOf(retained_id) == null and kata.completion.ownerOf(parent_id) == null, labels.ADOPTION_RESULTS);
}
