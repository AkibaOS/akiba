//! Completion Between Observer Registration And Queue Insertion

const drive = @import("tests").guest.support.drive;
const guard = @import("asm").interrupts.guard;
const inputs = @import("tests").constants.retention;
const kata = @import("mirai").kata;
const labels = @import("tests").strings.retention;
const sensei = @import("mirai").sensei;
const support = @import("tests").guest.mirai.sensei.support;
const thread = @import("mirai").thread;
const verify = @import("tests").guest.support.verify;

var target_id: u64 = 0;
var armed: bool = false;
var intercepted: bool = false;
var returned: bool = false;

pub fn registered(identifier: u64) void {
    if (!armed or identifier != target_id) return;
    armed = false;
    const flags = guard.acquire();
    defer guard.release(flags);
    const record = kata.completion.lifetime.borrow(identifier) catch |failure| verify.failure(failure);
    const current = thread.state.getCurrent().?;
    const window = record.Observers == 2 and record.Waiters.Count == 0 and record.Outcome == null and
        record.OwnerID == current.Owner.ID and current.Status == .Running;
    kata.completion.lifetime.drop(identifier);
    verify.require(window, labels.RACE_WINDOW);
    const target = kata.state.findByID(identifier).?;
    kata.finish.terminate(target, .{ .Exited = inputs.TARGET_RESULT }) catch |failure| verify.failure(failure);
    const result = kata.completion.lifetime.collect(identifier) catch |failure| verify.failure(failure);
    verify.require(result == .Exited and result.Exited == inputs.TARGET_RESULT and record.Collected and record.Reclaimed and
        record.Observers == 1 and record.Waiters.Count == 0 and kata.state.findByID(identifier) == null, labels.RACE_COLLECT);
    intercepted = true;
}

fn waiter(_: ?*anyopaque) callconv(.{ .x86_64_sysv = .{} }) noreturn {
    const result = kata.wait.waitFor(target_id) catch |failure| verify.failure(failure);
    verify.require(intercepted and result == .Exited and result.Exited == inputs.TARGET_RESULT, labels.RACE_RETURN);
    returned = true;
    thread.finish.complete();
}

fn subjectEntry(_: ?*anyopaque) callconv(.{ .x86_64_sysv = .{} }) noreturn {
    thread.finish.complete();
}

pub fn run() !void {
    target_id = 0;
    armed = false;
    intercepted = false;
    returned = false;
    const watcher = try kata.create.create();
    const watcher_id = watcher.ID;
    defer cleanup(watcher_id);
    {
        const flags = guard.acquire();
        defer guard.release(flags);
        errdefer cleanup(watcher_id);
        try sensei.control.start(try thread.create.create(watcher, waiter, null));
        const subject = try kata.create.createFor(watcher);
        target_id = subject.ID;
        try sensei.control.start(try thread.create.create(subject, subjectEntry, null));
        armed = true;
    }
    drive.run();
    const result = try kata.completion.lifetime.collect(watcher_id);
    verify.require(intercepted and returned and !armed and result == .Completed and
        kata.state.findByID(target_id) == null and kata.state.findByID(watcher_id) == null and
        kata.completion.storage.ownerOf(target_id) == null and kata.completion.storage.ownerOf(watcher_id) == null, labels.RACE_RELEASE);
}

fn cleanup(watcher_id: u64) void {
    armed = false;
    support.dispose(watcher_id) catch |failure| verify.failure(failure);
    if (target_id != 0) support.dispose(target_id) catch |failure| verify.failure(failure);
}
