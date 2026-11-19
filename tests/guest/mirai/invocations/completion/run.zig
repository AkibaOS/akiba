//! Managed Persona Completion Check Controller

const buffers = @import("tests").guest.mirai.invocations.completion.buffers;
const drive = @import("tests").guest.support.drive;
const harness = @import("tests").guest.mirai.postman.harness;
const kata = @import("mirai").kata;
const labels = @import("tests").strings.completion;
const outcomes = @import("tests").guest.mirai.invocations.completion.outcomes;
const ownership = @import("tests").guest.mirai.invocations.completion.ownership;
const sensei = @import("mirai").sensei;
const thread = @import("mirai").thread;
const verify = @import("tests").guest.support.verify;
const waiting = @import("tests").guest.mirai.invocations.completion.waiting;

var completed: bool = false;

pub fn run() !void {
    completed = false;
    const registered = sensei.state.getState().RegisteredCount;
    const owner = try kata.create.create();
    const identifier = owner.ID;
    defer harness.dispose(identifier);
    try sensei.control.start(try thread.create.create(owner, entry, null));
    drive.run();
    const outcome = try kata.completion.lifetime.collect(identifier);
    verify.require(completed and outcome == .Completed and kata.state.findByID(identifier) == null and
        kata.completion.storage.ownerOf(identifier) == null and sensei.state.getState().RegisteredCount == registered, labels.CLEANUP);
}

fn entry(_: ?*anyopaque) callconv(.{ .x86_64_sysv = .{} }) noreturn {
    outcomes.run() catch |failure| verify.failure(failure);
    buffers.run() catch |failure| verify.failure(failure);
    ownership.run() catch |failure| verify.failure(failure);
    waiting.run() catch |failure| verify.failure(failure);
    completed = true;
    thread.finish.complete();
}
