//! Kata Lifecycle Regressions

const drive = @import("tests").guest.support.drive;
const guard = @import("asm").interrupts.guard;
const kata = @import("mirai").kata;
const labels = @import("tests").strings.guest;
const sensei = @import("mirai").sensei;
const thread = @import("mirai").thread;
const verify = @import("tests").verify;

const Queue = sensei.types.queue.Queue;

var waiters: Queue = .{};
var released: bool = false;

fn ready(_: ?*anyopaque) bool {
    return released;
}

fn entry(_: ?*anyopaque) callconv(.{ .x86_64_sysv = .{} }) noreturn {
    sensei.wait.blockUntil(&waiters, ready, null) catch |failure| verify.failure(failure);
    thread.finish.complete();
}

pub fn run() !void {
    const aborted = try kata.create.create();
    const aborted_id = aborted.ID;
    const unstarted = try thread.create.create(aborted, entry, null);
    verify.require(aborted.State == .Born and aborted.ThreadCount == 1 and aborted.LiveThreadCount == 0 and
        aborted.RunnableThreadCount == 0, labels.KATA_BORN);
    try thread.destroy.destroy(unstarted);
    try kata.destroy.destroy(aborted);
    verify.require(kata.completion.lifetime.peek(aborted_id) == null and kata.completion.storage.ownerOf(aborted_id) == null, labels.KATA_ABORT);
    const owner = try kata.create.create();
    const id = owner.ID;
    const target = try thread.create.create(owner, entry, null);
    const flags = guard.acquire();
    try sensei.control.start(target);
    verify.require(owner.State == .Alive and owner.LiveThreadCount == 1 and owner.RunnableThreadCount == 1, labels.KATA_ALIVE);
    guard.release(flags);
    drive.run();
    verify.require(owner.State == .Sleeping and owner.LiveThreadCount == 1 and owner.RunnableThreadCount == 0, labels.KATA_SLEEPING);
    const wake_flags = guard.acquire();
    released = true;
    _ = try sensei.wait.wakeOne(&waiters);
    verify.require(owner.State == .Alive and owner.RunnableThreadCount == 1, labels.KATA_WAKE);
    guard.release(wake_flags);
    drive.run();
    verify.require(kata.state.findByID(id) == null and kata.completion.lifetime.peek(id).? == .Completed, labels.KATA_COMPLETE);
    _ = try kata.completion.lifetime.collect(id);
}
