//! Completion Ownership And Observer Regressions

const drive = @import("tests").guest.support.drive;
const guard = @import("asm").interrupts.guard;
const inputs = @import("tests").guest.constants.guest;
const kata = @import("mirai").kata;
const labels = @import("tests").guest.strings.guest;
const sensei = @import("mirai").sensei;
const thread = @import("mirai").thread;
const verify = @import("tests").guest.support.verify;

const Queue = sensei.types.queue.links.Queue;

var blocked: Queue = .{};
var target_id: u64 = 0;
var observed: bool = false;

fn never(_: ?*anyopaque) bool {
    return false;
}

fn targetEntry(_: ?*anyopaque) callconv(.{ .x86_64_sysv = .{} }) noreturn {
    sensei.wait.blockUntil(&blocked, never, null) catch |failure| verify.failure(failure);
    @panic(labels.INVALID_STATE);
}

fn observerEntry(_: ?*anyopaque) callconv(.{ .x86_64_sysv = .{} }) noreturn {
    var denied = false;
    if (kata.completion.lifetime.collect(target_id)) |_| {} else |failure| {
        denied = failure == error.NotOwner;
    }
    verify.require(denied, labels.WAIT_OWNER);
    const result = kata.wait.waitFor(target_id) catch |failure| verify.failure(failure);
    verify.require(result == .Exited and result.Exited == inputs.EXIT_RESULT, labels.WAIT_COPY);
    observed = true;
    thread.finish.complete();
}

pub fn run() !void {
    const target = try kata.create.create();
    target_id = target.ID;
    const watcher = try kata.create.create();
    const watcher_id = watcher.ID;
    const flags = guard.acquire();
    try sensei.control.start(try thread.create.create(target, targetEntry, null));
    try sensei.control.start(try thread.create.create(watcher, observerEntry, null));
    guard.release(flags);
    drive.run();
    verify.require(watcher.State == .Sleeping, labels.WAIT_BLOCKED);
    const collect_flags = guard.acquire();
    try kata.finish.terminate(target, .{ .Exited = inputs.EXIT_RESULT });
    _ = try kata.completion.lifetime.collect(target_id);
    verify.require(kata.completion.lifetime.peek(target_id) == null and kata.completion.storage.ownerOf(target_id) != null, labels.WAIT_RETAINED);
    guard.release(collect_flags);
    drive.run();
    verify.require(observed and kata.completion.storage.ownerOf(target_id) == null, labels.WAIT_RELEASE);
    _ = try kata.completion.lifetime.collect(watcher_id);
    try cancellation();
}

fn cancellation() !void {
    const target = try kata.create.create();
    target_id = target.ID;
    const watcher = try kata.create.create();
    const watcher_id = watcher.ID;
    const flags = guard.acquire();
    try sensei.control.start(try thread.create.create(target, targetEntry, null));
    try sensei.control.start(try thread.create.create(watcher, observerEntry, null));
    guard.release(flags);
    drive.run();
    try kata.finish.terminate(watcher, .Completed);
    const reference = try kata.completion.lifetime.borrow(target_id);
    verify.require(reference.Observers == 1 and reference.Waiters.Count == 0, labels.WAIT_CANCEL);
    kata.completion.lifetime.drop(target_id);
    try kata.finish.terminate(target, .Completed);
    _ = try kata.completion.lifetime.collect(target_id);
    _ = try kata.completion.lifetime.collect(watcher_id);
}
