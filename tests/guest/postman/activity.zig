//! Verify Owned Completion Wakeups And Child Stop Requests

const std = @import("std");

const completion = @import("tests").guest.completion.support;
const copy = @import("mirai").user.copy.transfer;
const harness = @import("tests").guest.postman.harness;
const inputs = @import("tests").guest.constants.postman.transport;
const kata = @import("mirai").kata;
const outcomes = @import("tests").guest.constants.completion.outcomes;

const Operation = @import("tests").guest.types.postman.fixtures.Operation;

pub fn run() !void {
    try timedCompletion();
    try stopped();
    try finished();
}

fn timedCompletion() !void {
    var client = try harness.create();
    defer harness.dispose(client.ID);
    var wait = completion.operation(&client, outcomes.WAIT);
    wait.Service = .WaitCompletionTimed;
    wait.ServiceValue = null;
    wait.First = .{ .Indirect = client.Data + inputs.TICKET_OFFSET };
    wait.LetterType = inputs.DEADLINE_TICKS;
    try harness.install(&client, &.{ .{ .Service = .Query }, wait });
    try harness.start(&client);
    try harness.waitStep(&client, 1);
    var child = try harness.child(&client);
    defer completion.dispose(child.ID);
    try harness.install(&child, &.{.{ .Service = .Query }});
    try harness.start(&child);
    try harness.waitStep(&child, 1);
    try copy.write(client.Owner, client.Data + inputs.TICKET_OFFSET, std.mem.asBytes(&child.ID));
    try harness.advance(&client, 1);
    try harness.waitTimedStep(&client, 2, inputs.DEADLINE_TICKS);
    const record = kata.completion.storage.find(child.ID) orelse return error.InvalidFixture;
    try harness.check(try harness.resultIs(&client, 2, .TimedOut, 0) and record.Observers == 0 and record.Waiters.Count == 0);
    try harness.advance(&client, 2);
}

fn stopped() !void {
    var client = try harness.create();
    defer harness.dispose(client.ID);
    const address = client.Data + inputs.TICKET_OFFSET;
    const stop: Operation = .{ .Service = .StopChild, .First = .{ .Indirect = address }, .Second = inputs.PROVISION_RESULT };
    var activity = harness.receive(&client, inputs.OUTPUT_BYTES);
    activity.Service = .ReceiveActivity;
    var collect = completion.operation(&client, outcomes.COLLECT);
    collect.First = stop.First;
    try harness.install(&client, &.{ .{ .Service = .Query }, stop, activity, collect });
    try harness.start(&client);
    try harness.waitStep(&client, 1);
    var child = try harness.child(&client);
    defer completion.dispose(child.ID);
    try harness.install(&child, &.{.{ .Service = .Query }});
    try harness.start(&child);
    try harness.waitStep(&child, 1);
    var unrelated = try harness.create();
    defer harness.dispose(unrelated.ID);
    try harness.install(&unrelated, &.{.{ .Service = .StopChild, .First = .{ .Immediate = child.ID } }});
    try harness.start(&unrelated);
    try harness.waitStep(&unrelated, 1);
    try harness.check(try harness.resultIs(&unrelated, 1, .NotOwner, 0) and kata.state.findByID(child.ID) != null);
    try harness.advance(&unrelated, 1);
    try copy.write(client.Owner, address, std.mem.asBytes(&child.ID));
    try harness.advance(&client, 1);
    try harness.waitStep(&client, 2);
    try harness.check(try harness.resultIs(&client, 2, .Success, 0));
    try harness.advance(&client, 2);
    try harness.waitStep(&client, 3);
    try harness.check(try harness.resultIs(&client, 3, .ChildReady, child.ID));
    try harness.advance(&client, 3);
    try harness.waitStep(&client, 4);
    const receipt = try completion.record(&client);
    try harness.check(try harness.resultIs(&client, 4, .Success, outcomes.RECORD_BYTES) and
        receipt.Kind == outcomes.EXITED and receipt.Result == inputs.PROVISION_RESULT and kata.completion.storage.ownerOf(child.ID) == null);
    try harness.advance(&client, 4);
}

fn finished() !void {
    var client = try harness.create();
    defer harness.dispose(client.ID);
    var activity = harness.receive(&client, inputs.OUTPUT_BYTES);
    activity.Service = .ReceiveActivity;
    try harness.install(&client, &.{ .{ .Service = .Query }, activity });
    try harness.start(&client);
    try harness.waitStep(&client, 1);
    var child = try harness.child(&client);
    defer completion.dispose(child.ID);
    try harness.install(&child, &.{.{ .Service = .FinishThread }});
    try harness.advance(&client, 1);
    try harness.waitBlocked(&client);
    try harness.start(&child);
    try harness.waitStep(&client, 2);
    try harness.check(try harness.resultIs(&client, 2, .ChildReady, child.ID));
    try harness.advance(&client, 2);
}
