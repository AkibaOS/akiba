//! Persona Call Reply Ticket And Collection Regressions

const constants = @import("tests").guest.constants.postman;
const harness = @import("tests").guest.mirai.postman.harness;
const labels = @import("tests").guest.strings.postman;
const postmanwire = @import("tests").fixtures.constants.postman;
const verify = @import("tests").guest.support.verify;

pub fn run() !void {
    var server = try harness.create();
    defer harness.dispose(server.ID);
    var client = try harness.create();
    defer harness.dispose(client.ID);
    try harness.descriptor(&client, server.ID, 0);
    try harness.input(&server, &constants.REPLY);
    var wrong_ticket = harness.reply(&server);
    wrong_ticket.First = .{ .Immediate = 0 };
    try harness.install(&server, &.{
        harness.receive(&server, constants.OUTPUT_BYTES), wrong_ticket,
        harness.receive(&server, constants.OUTPUT_BYTES), harness.reply(&server),
        harness.reply(&server),
    });
    var invalid_collect = harness.collect(&client, constants.REPLY.len);
    invalid_collect.First = .{ .Immediate = constants.INVALID_ADDRESS };
    try harness.install(&client, &.{
        harness.call(&client),                            harness.call(&client),                            harness.collect(&client, 0), invalid_collect,
        harness.collect(&client, constants.OUTPUT_BYTES), harness.collect(&client, constants.OUTPUT_BYTES),
    });
    try harness.start(&server);
    try harness.waitBlocked(&server);
    try harness.start(&client);
    try harness.waitStep(&server, 1);
    try harness.waitBlocked(&client);
    const request = try harness.header(&server);
    const source = try harness.mailbox(&client);
    const destination = try harness.mailbox(&server);
    const client_record = try harness.record(&client);
    const server_record = try harness.record(&server);
    const pending = client_record.Pending orelse return error.InvalidFixture;
    verify.require((try harness.resultIs(&server, 1, .Success, constants.REQUEST.len)) and
        (try harness.payloadIs(&server, &constants.REQUEST)) and request.Sender == client.ID and
        request.Type == postmanwire.CALL_TYPE and request.Length == constants.REQUEST.len and request.ReplyTicket != 0 and
        pending.Status == .Delivered and pending.Ticket == request.ReplyTicket and server_record.Serving == pending and
        source.Outgoing == 1 and destination.Held == 1 and destination.Queued == 0, labels.CALL_DELIVERY);
    var sibling = try harness.sibling(&server, 1);
    var stolen = harness.reply(&sibling);
    stolen.First = .{ .Immediate = request.ReplyTicket };
    try harness.install(&sibling, &.{stolen});
    try harness.start(&sibling);
    try harness.waitStep(&sibling, 1);
    verify.require((try harness.resultIs(&sibling, 1, .InvalidReply, 0)) and server_record.Serving == pending and
        pending.Status == .Delivered and client.Target.?.Status == .Blocked, labels.TICKET_THREAD);
    try harness.advance(&server, 1);
    try harness.waitStep(&server, 2);
    const invalid_preserved = (try harness.resultIs(&server, 2, .InvalidReply, 0)) and server_record.Serving == pending;
    try harness.advance(&server, 2);
    try harness.waitStep(&server, 3);
    verify.require(invalid_preserved and (try harness.resultIs(&server, 3, .Busy, 0)) and
        server_record.Serving == pending and pending.Status == .Delivered and
        source.Outgoing == 1 and destination.Held == 1, labels.SERVING_BUSY);
    try harness.advance(&server, 3);
    try harness.waitStep(&server, 4);
    try harness.waitStep(&client, 1);
    try harness.input(&server, &constants.REPLACEMENT);
    try harness.advance(&server, 4);
    try harness.waitStep(&server, 5);
    verify.require((try harness.resultIs(&server, 4, .Success, 0)) and
        (try harness.resultIs(&server, 5, .InvalidReply, 0)) and server_record.Serving == null and
        client_record.Pending == pending and pending.Status == .Replied and pending.Ticket == 0 and
        source.Outgoing == 1 and destination.Held == 1, labels.REPLY_ONESHOT);
    var retained = try harness.resultIs(&client, 1, .BufferTooSmall, constants.REPLY.len);
    try harness.advance(&client, 1);
    try harness.waitStep(&client, 2);
    retained = retained and (try harness.resultIs(&client, 2, .Busy, 0));
    try harness.advance(&client, 2);
    try harness.waitStep(&client, 3);
    retained = retained and (try harness.resultIs(&client, 3, .BufferTooSmall, constants.REPLY.len));
    try harness.advance(&client, 3);
    try harness.waitStep(&client, 4);
    retained = retained and (try harness.resultIs(&client, 4, .InvalidAddress, 0)) and
        (try harness.untouched(&client)) and client_record.Pending == pending and source.Outgoing == 1 and destination.Held == 1;
    try harness.advance(&client, 4);
    try harness.waitStep(&client, 5);
    const response = try harness.header(&client);
    const collected = (try harness.resultIs(&client, 5, .Success, constants.REPLY.len)) and
        (try harness.payloadIs(&client, &constants.REPLY)) and response.Sender == server.ID and
        response.Type == postmanwire.REPLY_TYPE and response.Length == constants.REPLY.len and response.ReplyTicket == 0;
    try harness.advance(&client, 5);
    try harness.waitStep(&client, 6);
    verify.require(retained and collected and (try harness.resultIs(&client, 6, .InvalidState, 0)) and
        client_record.Pending == null and source.Outgoing == 0 and destination.Held == 0, labels.COLLECT_RETRY);
}
