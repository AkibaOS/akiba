//! Verify Calls Time Out Without Losing Pending Or Serving Ownership

const std = @import("std");

const copy = @import("mirai").user.copy.transfer;
const harness = @import("tests").guest.postman.harness;
const guard = @import("asm").interrupts.guard;
const inputs = @import("tests").guest.constants.postman.transport;
const labels = @import("tests").guest.strings.postman.deadline;
const postman = @import("mirai").postman;
const print = @import("mirai").boot.sequence.print;
const sensei = @import("mirai").sensei;

const DeadlineError = @import("tests").guest.errors.postman.deadline.DeadlineError;
const InvocationResult = @import("tests").guest.types.postman.fixtures.InvocationResult;

pub fn run() !void {
    try arbitration();
    try expires(false);
    try expires(true);
    try answered();
}

fn arbitration() !void {
    const flags = guard.acquire();
    defer guard.release(flags);
    var timer: sensei.types.record.Record = .{};
    defer sensei.deadline.cancel(&timer);
    try sensei.deadline.arm(&timer, inputs.DEADLINE_TICKS);
    const until = timer.Deadline.?;
    sensei.deadline.expire(until);
    sensei.deadline.completed(&timer);
    if (!timer.TimedOut or timer.Deadline != null) return DeadlineError.InvalidDeadlineWinner;
    sensei.deadline.cancel(&timer);
    try sensei.deadline.arm(&timer, inputs.DEADLINE_TICKS);
    sensei.deadline.completed(&timer);
    sensei.deadline.expire(until);
    if (timer.TimedOut or timer.Deadline != null) return DeadlineError.InvalidDeadlineWinner;
}

fn answered() !void {
    var client = try harness.create();
    defer harness.dispose(client.ID);
    var server = try harness.create();
    defer harness.dispose(server.ID);
    try harness.input(&server, &inputs.REPLY);
    try harness.descriptor(&client, server.ID, inputs.OUTPUT_BYTES);
    var call = harness.call(&client);
    call.Service = .CallTimed;
    call.Second = inputs.DEADLINE_TICKS;
    try harness.install(&client, &.{call});
    try harness.install(&server, &.{ harness.receive(&server, inputs.OUTPUT_BYTES), harness.reply(&server) });
    try harness.start(&server);
    try harness.waitBlocked(&server);
    try harness.start(&client);
    try harness.waitStep(&server, 1);
    try harness.advance(&server, 1);
    try harness.waitStep(&client, 1);
    const record = sensei.registry.find(client.Target.?) orelse return DeadlineError.RetainedDeadline;
    if (!try harness.resultIs(&client, 1, .Success, inputs.REPLY.len) or !try harness.payloadIs(&client, &inputs.REPLY) or
        record.Deadline != null or record.TimedOut) return DeadlineError.RetainedDeadline;
    try harness.advance(&client, 1);
    try harness.advance(&server, 2);
}

fn expires(comptime delivered: bool) !void {
    var client = try harness.create();
    defer harness.dispose(client.ID);
    var server = try harness.create();
    defer harness.dispose(server.ID);
    try harness.descriptor(&client, server.ID, inputs.OUTPUT_BYTES);
    var call = harness.call(&client);
    call.Service = .CallTimed;
    call.Second = inputs.DEADLINE_TICKS;
    try harness.install(&client, &.{call});
    if (delivered) {
        try harness.install(&server, &.{ harness.receive(&server, inputs.OUTPUT_BYTES), harness.reply(&server) });
        try harness.start(&server);
        try harness.waitBlocked(&server);
    } else {
        try harness.install(&server, &.{.{ .Service = .Query }});
        try harness.start(&server);
        try harness.waitStep(&server, 1);
    }
    try harness.start(&client);
    if (delivered) try harness.waitStep(&server, 1);
    try harness.waitTimedStep(&client, 1, inputs.DEADLINE_TICKS);
    if (!try harness.resultIs(&client, 1, .TimedOut, 0)) {
        var result: InvocationResult = undefined;
        try copy.read(client.Owner, std.mem.asBytes(&result), client.Data + inputs.RESULT_OFFSET);
        print.log(labels.RESULT, .{ result.Status, result.Value, @as(u64, if (delivered) 1 else 0) });
        return DeadlineError.UnexpectedTimeoutResult;
    }
    if ((try harness.record(&client)).Pending != null or (try harness.mailbox(&client)).Outgoing != 0) return DeadlineError.RetainedTimedOutClient;
    if (delivered) {
        const header = try harness.header(&server);
        try copy.write(server.Owner, server.Data + inputs.TICKET_OFFSET, std.mem.asBytes(&header.ReplyTicket));
        try harness.advance(&server, 1);
        try harness.waitStep(&server, 2);
        if (!try harness.resultIs(&server, 2, .PeerGone, 0)) return DeadlineError.UnexpectedLateReply;
        try harness.advance(&server, 2);
    }
    if ((try harness.mailbox(&server)).Held != 0) return DeadlineError.RetainedTimedOutLetter;
    if (!postman.call.ready(@ptrCast(client.Target.?))) return DeadlineError.TimedOutClientNotReady;
    try harness.advance(&client, 1);
}
