//! Simultaneous Thread Pending And Serving Ownership

const std = @import("std");

const budget = @import("tests").guest.support.allocation;
const copy = @import("mirai").user.copy.transfer;
const harness = @import("tests").guest.mirai.postman.harness;
const inputs = @import("tests").guest.constants.postman;
const labels = @import("tests").guest.strings.postman;
const verify = @import("tests").guest.support.verify;

pub fn run() !void {
    try nested(false);
    try nested(true);
}

fn nested(comptime cancel: bool) !void {
    defer budget.clear();
    var client = try harness.create();
    defer harness.dispose(client.ID);
    var middle = try harness.create();
    defer harness.dispose(middle.ID);
    var backend = try harness.create();
    defer harness.dispose(backend.ID);
    try harness.descriptor(&client, middle.ID, inputs.OUTPUT_BYTES);
    try harness.descriptor(&middle, backend.ID, inputs.OUTPUT_BYTES);
    try harness.input(&backend, &inputs.REPLY);
    var reply = harness.reply(&middle);
    reply.First = .{ .Indirect = middle.Data + inputs.TICKET_OFFSET };
    try harness.install(&client, &.{harness.call(&client)});
    try harness.install(&middle, &.{ harness.receive(&middle, inputs.OUTPUT_BYTES), harness.call(&middle), reply });
    try harness.install(&backend, &.{ harness.receive(&backend, inputs.OUTPUT_BYTES), harness.reply(&backend) });
    try harness.start(&backend);
    try harness.waitBlocked(&backend);
    try harness.start(&middle);
    try harness.waitBlocked(&middle);
    try harness.start(&client);
    try harness.waitStep(&middle, 1);
    const incoming = try harness.header(&middle);
    try copy.write(middle.Owner, middle.Data + inputs.TICKET_OFFSET, std.mem.asBytes(&incoming.ReplyTicket));
    try harness.advance(&middle, 1);
    try harness.waitStep(&backend, 1);
    try harness.waitBlocked(&middle);
    const record = try harness.record(&middle);
    const pending = record.Pending orelse return error.InvalidFixture;
    const serving = record.Serving orelse return error.InvalidFixture;
    verify.require(pending != serving and pending.Status == .Delivered and serving.Status == .Delivered and
        pending.Client == record and serving.Receiver == record and (try harness.mailbox(&middle)).Outgoing == 1 and
        (try harness.mailbox(&middle)).Held == 1, labels.DUPLEX);
    try harness.input(&middle, &inputs.REPLY);
    budget.arm(0);
    if (cancel) {
        harness.dispose(middle.ID);
        try harness.waitStep(&client, 1);
        try harness.advance(&backend, 1);
        try harness.waitStep(&backend, 2);
        verify.require((try harness.resultIs(&client, 1, .PeerGone, 0)) and
            (try harness.resultIs(&backend, 2, .PeerGone, 0)) and (try harness.mailbox(&client)).Outgoing == 0 and
            (try harness.mailbox(&backend)).Held == 0, labels.DUPLEX_CANCEL);
    } else {
        try harness.advance(&backend, 1);
        try harness.waitStep(&backend, 2);
        try harness.waitStep(&middle, 2);
        try harness.check(record.Pending == null and record.Serving == serving);
        try harness.advance(&middle, 2);
        try harness.waitStep(&middle, 3);
        try harness.waitStep(&client, 1);
        verify.require((try harness.resultIs(&middle, 2, .Success, inputs.REPLY.len)) and
            (try harness.resultIs(&middle, 3, .Success, 0)) and (try harness.resultIs(&client, 1, .Success, inputs.REPLY.len)) and
            (try harness.payloadIs(&client, &inputs.REPLY)) and record.Pending == null and record.Serving == null, labels.DUPLEX_REPLY);
    }
    budget.clear();
}
