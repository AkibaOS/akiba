//! Persona Completion Blocking Collection Races And Cancellation

const std = @import("std");

const copy = @import("mirai").user.copy.transfer;
const guard = @import("asm").interrupts.guard;
const harness = @import("tests").guest.mirai.postman.harness;
const inputs = @import("tests").guest.constants.completion;
const kata = @import("mirai").kata;
const labels = @import("tests").guest.strings.completion;
const locations = @import("tests").guest.constants.postman;
const sensei = @import("mirai").sensei;
const support = @import("tests").guest.mirai.invocations.completion.support;
const thread = @import("mirai").thread;
const types = @import("tests").guest.types.completion;
const user = @import("mirai").user;
const verify = @import("tests").guest.support.verify;

pub fn run() !void {
    try blocked();
    try collected();
    try revoked();
    try cancelled();
}

fn blocked() !void {
    var actor = try harness.create();
    defer harness.dispose(actor.ID);
    try harness.install(&actor, &.{ .{ .Service = .Yield }, support.operation(&actor, inputs.WAIT), support.operation(&actor, inputs.COLLECT) });
    try harness.start(&actor);
    try harness.waitStep(&actor, 1);
    const target = try support.sleeping(actor.Owner);
    defer support.dispose(target.ID);
    try support.identify(&actor, target.ID);
    try harness.advance(&actor, 1);
    try harness.waitBlocked(&actor);
    const record = try kata.completion.lifetime.borrow(target.ID);
    const registered = record.Observers == 2 and record.Waiters.Count == 1 and actor.Owner.State == .Sleeping;
    kata.completion.lifetime.drop(target.ID);
    try support.terminate(target.ID);
    try harness.waitStep(&actor, 2);
    const expected: types.Record = .{ .Kind = inputs.EXITED, .Result = inputs.RESULT };
    verify.require(registered and (try support.response(&actor, 2, inputs.SUCCESS, inputs.RECORD_BYTES)) and
        std.meta.eql(expected, try support.record(&actor)) and (try support.guarded(&actor)) and
        kata.completion.lifetime.peek(target.ID) != null and actor.Owner.State == .Alive, labels.WAITING);
    try harness.advance(&actor, 2);
    try harness.waitStep(&actor, 3);
    verify.require((try support.response(&actor, 3, inputs.SUCCESS, inputs.RECORD_BYTES)) and
        kata.completion.storage.ownerOf(target.ID) == null, labels.EXITED);
}

fn collected() !void {
    var owner = try harness.create();
    defer harness.dispose(owner.ID);
    var first = try harness.create();
    defer harness.dispose(first.ID);
    var second = try harness.create();
    defer harness.dispose(second.ID);
    try harness.install(&owner, &.{ .{ .Service = .Yield }, support.operation(&owner, inputs.COLLECT) });
    try harness.install(&first, &.{ .{ .Service = .Yield }, support.operation(&first, inputs.WAIT) });
    try harness.install(&second, &.{ .{ .Service = .Yield }, support.operation(&second, inputs.WAIT) });
    try harness.start(&owner);
    try harness.start(&first);
    try harness.start(&second);
    try harness.waitStep(&owner, 1);
    try harness.waitStep(&first, 1);
    try harness.waitStep(&second, 1);
    const target = try support.sleeping(owner.Owner);
    defer support.dispose(target.ID);
    try support.identify(&owner, target.ID);
    try support.identify(&first, target.ID);
    try support.identify(&second, target.ID);
    try harness.advance(&first, 1);
    try harness.advance(&second, 1);
    try harness.waitBlocked(&first);
    try harness.waitBlocked(&second);
    const record = try kata.completion.lifetime.borrow(target.ID);
    const registered = record.Observers == 3 and record.Waiters.Count == 2;
    kata.completion.lifetime.drop(target.ID);
    {
        const flags = guard.acquire();
        defer guard.release(flags);
        try support.terminate(target.ID);
        try harness.advance(&owner, 1);
        sensei.run.rescheduleTo(false, owner.Target.?);
    }
    try harness.waitStep(&owner, 2);
    try harness.waitStep(&first, 2);
    try harness.waitStep(&second, 2);
    const expected: types.Record = .{ .Kind = inputs.EXITED, .Result = inputs.RESULT };
    verify.require(registered and (try support.response(&owner, 2, inputs.SUCCESS, inputs.RECORD_BYTES)) and
        (try support.response(&first, 2, inputs.SUCCESS, inputs.RECORD_BYTES)) and
        (try support.response(&second, 2, inputs.SUCCESS, inputs.RECORD_BYTES)) and
        std.meta.eql(expected, try support.record(&owner)) and std.meta.eql(expected, try support.record(&first)) and
        std.meta.eql(expected, try support.record(&second)) and kata.completion.storage.ownerOf(target.ID) == null and
        kata.state.findByID(target.ID) == null, labels.COLLECTED);
}

fn revoked() !void {
    var actor = try harness.create();
    defer harness.dispose(actor.ID);
    try user.memory.allocate.allocate(actor.Owner, inputs.REVOKED_OUTPUT);
    const untouched = [_]u8{locations.GUARD_BYTE} ** locations.OUTPUT_BYTES;
    try copy.write(actor.Owner, inputs.REVOKED_OUTPUT, &untouched);
    var wait = support.operation(&actor, inputs.WAIT);
    wait.Second = inputs.REVOKED_OUTPUT;
    try harness.install(&actor, &.{ .{ .Service = .Yield }, wait, support.operation(&actor, inputs.COLLECT) });
    try harness.start(&actor);
    try harness.waitStep(&actor, 1);
    const target = try support.sleeping(actor.Owner);
    defer support.dispose(target.ID);
    try support.identify(&actor, target.ID);
    try harness.advance(&actor, 1);
    try harness.waitBlocked(&actor);
    try user.memory.finalize.finalize(actor.Owner, inputs.REVOKED_OUTPUT, .ReadOnly);
    try support.terminate(target.ID);
    try harness.waitStep(&actor, 2);
    var output: [locations.OUTPUT_BYTES]u8 = undefined;
    try copy.read(actor.Owner, &output, inputs.REVOKED_OUTPUT);
    const record = try kata.completion.lifetime.borrow(target.ID);
    const released = record.Observers == 1 and record.Waiters.Count == 0 and record.Reclaimed and !record.Collected;
    kata.completion.lifetime.drop(target.ID);
    verify.require(released and (try support.response(&actor, 2, inputs.INVALID_ADDRESS, 0)) and
        std.mem.eql(u8, &untouched, &output), labels.REVOKED);
    try harness.advance(&actor, 2);
    try harness.waitStep(&actor, 3);
    verify.require((try support.response(&actor, 3, inputs.SUCCESS, inputs.RECORD_BYTES)) and
        kata.completion.storage.ownerOf(target.ID) == null, labels.EXITED);
}

fn cancelled() !void {
    var actor = try harness.create();
    defer harness.dispose(actor.ID);
    try harness.install(&actor, &.{ .{ .Service = .Yield }, support.operation(&actor, inputs.WAIT) });
    try harness.start(&actor);
    try harness.waitStep(&actor, 1);
    const target = try support.sleeping(thread.state.getCurrent().?.Owner);
    defer support.dispose(target.ID);
    try support.identify(&actor, target.ID);
    try harness.advance(&actor, 1);
    try harness.waitBlocked(&actor);
    harness.dispose(actor.ID);
    const record = try kata.completion.lifetime.borrow(target.ID);
    const released = record.Observers == 1 and record.Waiters.Count == 0 and record.Outcome == null;
    kata.completion.lifetime.drop(target.ID);
    verify.require(released and kata.state.findByID(actor.ID) == null and kata.completion.storage.ownerOf(actor.ID) == null, labels.CANCELLED);
}
