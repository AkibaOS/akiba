//! Coupled Thread Scheduler Wait And Transport Populations

const budget = @import("tests").guest.support.allocation;
const guard = @import("asm").interrupts.guard;
const inputs = @import("tests").guest.constants.pool;
const kata = @import("mirai").kata;
const labels = @import("tests").strings.sensei;
const memory = @import("mirai").memory;
const postman = @import("mirai").postman;
const sensei = @import("mirai").sensei;
const support = @import("tests").guest.mirai.sensei.support;
const thread = @import("mirai").thread;
const types = @import("tests").guest.types.sensei;
const verify = @import("tests").guest.support.verify;

const Thread = thread.types.thread.Thread;

var fixture: types.PopulationState = .{};
var identifiers = [_]u64{0} ** inputs.LIVE_COUNT;
var targets = [_]?*Thread{null} ** inputs.LIVE_COUNT;
var generations = [_]u64{0} ** inputs.LIVE_COUNT;

fn open(_: ?*anyopaque) bool {
    return fixture.Open;
}

fn targetEntry(_: ?*anyopaque) callconv(.{ .x86_64_sysv = .{} }) noreturn {
    const flags = guard.acquire();
    fixture.TargetParked = true;
    guard.release(flags);
    sensei.wait.blockUntil(&fixture.TargetWaiters, open, null) catch |failure| verify.failure(failure);
    thread.finish.complete();
}

fn waiterEntry(_: ?*anyopaque) callconv(.{ .x86_64_sysv = .{} }) noreturn {
    const current = thread.state.getCurrent().?;
    _ = postman.inbox.get(current.Owner) catch |failure| verify.failure(failure);
    _ = postman.record.get(current) catch |failure| verify.failure(failure);
    const flags = guard.acquire();
    fixture.Entered += 1;
    guard.release(flags);
    const outcome = kata.wait.waitFor(fixture.TargetID) catch |failure| verify.failure(failure);
    _ = guard.acquire();
    fixture.Received = fixture.Received and outcome == .Completed;
    fixture.Finished += 1;
    thread.finish.complete();
}

pub fn run() !void {
    defer {
        budget.clear();
        for (&identifiers) |*identifier| {
            if (identifier.* != 0) support.dispose(identifier.*) catch |failure| verify.failure(failure);
            identifier.* = 0;
        }
        if (fixture.TargetID != 0) support.dispose(fixture.TargetID) catch |failure| verify.failure(failure);
        _ = memory.stack.collect.collect();
    }
    fixture = .{};
    var registered: usize = 0;
    {
        const flags = guard.acquire();
        defer guard.release(flags);
        const scheduler = sensei.state.getState();
        registered = scheduler.RegisteredCount;
        const owner = try kata.create.create();
        fixture.TargetID = owner.ID;
        const target = try thread.create.create(owner, targetEntry, null);
        for (&identifiers, &targets, &generations) |*identifier, *entry, *generation| {
            const peer = try kata.create.create();
            identifier.* = peer.ID;
            entry.* = try thread.create.create(peer, waiterEntry, null);
            generation.* = thread.state.generation(entry.*.?).?;
        }
        try sensei.control.start(target);
        for (targets) |entry| try sensei.control.start(entry.?);
        var stable = scheduler.RegisteredCount == registered + inputs.LIVE_COUNT + 1 and scheduler.Ready.Count == inputs.LIVE_COUNT + 1;
        for (targets, generations) |entry, generation| {
            stable = stable and thread.state.owns(entry.?) and thread.state.generation(entry.?).? == generation and
                sensei.registry.find(entry.?) != null and entry.?.Managed and entry.?.Admitted;
        }
        verify.require(stable, labels.POPULATION_READY);
    }
    try support.drain(fixture.TargetID);
    {
        const flags = guard.acquire();
        defer guard.release(flags);
        const record = try kata.completion.lifetime.borrow(fixture.TargetID);
        var parked = fixture.TargetParked and fixture.TargetWaiters.Count == 1 and fixture.Entered == inputs.LIVE_COUNT and
            fixture.Finished == 0 and record.Observers == inputs.LIVE_COUNT + 1 and record.Waiters.Count == inputs.LIVE_COUNT;
        for (targets, identifiers, generations) |entry, identifier, generation| {
            const owner = kata.state.findByID(identifier);
            parked = parked and owner != null and owner.?.State == .Sleeping and entry.?.Status == .Blocked and
                thread.state.generation(entry.?).? == generation and postman.inbox.find(owner.?) != null and
                postman.record.find(entry.?) != null;
        }
        kata.completion.lifetime.drop(fixture.TargetID);
        verify.require(parked, labels.POPULATION_WAIT);
        fixture.Open = true;
        budget.arm(0);
        const awakened = try sensei.wait.wakeOne(&fixture.TargetWaiters);
        verify.require(awakened, labels.POPULATION_FINISH);
    }
    try support.drain(fixture.TargetID);
    const flags = guard.acquire();
    defer guard.release(flags);
    var complete = fixture.Finished == inputs.LIVE_COUNT and fixture.Received and fixture.TargetWaiters.Count == 0 and
        sensei.state.getState().RegisteredCount == registered and kata.state.findByID(fixture.TargetID) == null;
    for (&identifiers, targets) |*identifier, entry| {
        const outcome = kata.completion.lifetime.peek(identifier.*);
        complete = complete and outcome != null and outcome.? == .Completed and kata.state.findByID(identifier.*) == null and
            !thread.state.owns(entry.?);
        try support.dispose(identifier.*);
        identifier.* = 0;
    }
    const target_outcome = kata.completion.lifetime.peek(fixture.TargetID);
    complete = complete and target_outcome != null and target_outcome.? == .Completed;
    try support.dispose(fixture.TargetID);
    fixture.TargetID = 0;
    budget.clear();
    _ = memory.stack.collect.collect();
    verify.require(complete, labels.POPULATION_FINISH);
}
