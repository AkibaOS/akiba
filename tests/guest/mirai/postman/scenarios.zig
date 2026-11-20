//! Managed Postman Scenario Controller

const std = @import("std");

const harness = @import("tests").guest.mirai.postman.harness;
const kata = @import("mirai").kata;
const labels = @import("tests").guest.strings.postman;
const postman = @import("mirai").postman;
const scenarios = @import("tests").guest.mirai.postman;
const sensei = @import("mirai").sensei;
const support = @import("tests").guest.mirai.sensei.support;
const thread = @import("mirai").thread;
const types = @import("tests").guest.types.postman;
const verify = @import("tests").guest.support.verify;

var finished: bool = false;

fn execute(_: ?*anyopaque) callconv(.{ .x86_64_sysv = .{} }) noreturn {
    scenarios.delivery.run() catch |failure| verify.failure(failure);
    scenarios.receive.run() catch |failure| verify.failure(failure);
    scenarios.call.run() catch |failure| verify.failure(failure);
    scenarios.provision.run() catch |failure| verify.failure(failure);
    scenarios.staged.run() catch |failure| verify.failure(failure);
    scenarios.linked.run() catch |failure| verify.failure(failure);
    scenarios.retained.run() catch |failure| verify.failure(failure);
    scenarios.capacity.run() catch |failure| verify.failure(failure);
    scenarios.duplex.run() catch |failure| verify.failure(failure);
    scenarios.shutdown.run() catch |failure| verify.failure(failure);
    scenarios.growth.run() catch |failure| verify.failure(failure);
    finished = true;
    thread.finish.complete();
}

pub fn run() !void {
    if (!postman.state.getState().Initialized or !sensei.state.getState().Initialized) return types.FixtureError.InvalidFixture;
    finished = false;
    const before = harness.resources();
    const owner = try kata.create.create();
    const identifier = owner.ID;
    defer harness.dispose(identifier);
    try sensei.control.start(try thread.create.create(owner, execute, null));
    try support.drain(identifier);
    const outcome = kata.completion.lifetime.peek(identifier) orelse return types.FixtureError.InvalidFixture;
    harness.dispose(identifier);
    const after = harness.resources();
    verify.require(finished and outcome == .Completed and std.meta.eql(before, after) and
        kata.state.findByID(identifier) == null and kata.completion.storage.ownerOf(identifier) == null, labels.CLEANUP);
}
