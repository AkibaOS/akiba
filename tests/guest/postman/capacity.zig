//! Accepted Call Maximum Reply Without Further Allocation

const std = @import("std");

const arguments = @import("shared").persona.types.call;
const budget = @import("tests").guest.support.allocation;
const copy = @import("mirai").user.copy.transfer;
const harness = @import("tests").guest.postman.harness;
const inputs = @import("tests").guest.constants.postman.transport;
const labels = @import("tests").guest.strings.postman.witnesses;
const postman = @import("mirai").postman;
const postmanwire = @import("tests").fixtures.constants.postman;
const user = @import("mirai").user;
const verify = @import("tests").guest.support.verify;
const wire = @import("shared").persona.constants.postman;

var payload: [wire.MAX_PAYLOAD_BYTES]u8 = undefined;
var received: [wire.MAX_PAYLOAD_BYTES]u8 = undefined;

pub fn run() !void {
    defer budget.clear();
    var server = try harness.create();
    defer harness.dispose(server.ID);
    var client = try harness.create();
    defer harness.dispose(client.ID);
    try user.memory.allocate.allocate(server.Owner, server.Data + inputs.PAGE_BYTES);
    try user.memory.finalize.finalize(server.Owner, server.Data + inputs.PAGE_BYTES, .ReadWrite);
    try user.memory.allocate.allocate(client.Owner, client.Data + inputs.PAGE_BYTES);
    try user.memory.finalize.finalize(client.Owner, client.Data + inputs.PAGE_BYTES, .ReadWrite);
    for (&payload, 0..) |*byte, index| byte.* = @truncate(index);
    try copy.write(server.Owner, server.Data + inputs.PAGE_BYTES, &payload);
    const descriptor: arguments.Call = .{
        .Destination = server.ID,
        .Type = postmanwire.CALL_TYPE,
        .Request = client.Data + inputs.INPUT_OFFSET,
        .RequestLength = inputs.REQUEST.len,
        .Reply = client.Data + inputs.PAGE_BYTES,
        .ReplyCapacity = payload.len,
        .Metadata = client.Data + inputs.HEADER_OFFSET,
    };
    try copy.write(client.Owner, client.Data + inputs.CALL_OFFSET, std.mem.asBytes(&descriptor));
    var reply = harness.reply(&server);
    reply.First = .{ .Indirect = server.Data + inputs.TICKET_OFFSET };
    reply.Second = server.Data + inputs.PAGE_BYTES;
    reply.Third = payload.len;
    try harness.install(&server, &.{ harness.receive(&server, inputs.OUTPUT_BYTES), reply });
    try harness.install(&client, &.{harness.call(&client)});
    try harness.start(&server);
    try harness.waitBlocked(&server);
    try harness.start(&client);
    try harness.waitStep(&server, 1);
    try harness.waitBlocked(&client);
    const request = try harness.header(&server);
    const serving = (try harness.record(&server)).Serving orelse return error.InvalidFixture;
    try copy.write(server.Owner, server.Data + inputs.TICKET_OFFSET, std.mem.asBytes(&request.ReplyTicket));
    budget.arm(0);
    try harness.advance(&server, 1);
    try harness.waitStep(&server, 2);
    try harness.waitStep(&client, 1);
    try copy.read(client.Owner, &received, client.Data + inputs.PAGE_BYTES);
    verify.require((try harness.resultIs(&server, 2, .Success, 0)) and
        (try harness.resultIs(&client, 1, .Success, payload.len)) and std.mem.eql(u8, &received, &payload) and
        (try harness.record(&client)).Pending == null and (try harness.record(&server)).Serving == null and
        !postman.storage.owns(serving), labels.MAXIMUM_REPLY);
    budget.clear();
}
