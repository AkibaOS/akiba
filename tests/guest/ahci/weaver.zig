//! Prove The Installed Weaver Launches Through The Actual AFS Driver

const std = @import("std");

const completion = @import("tests").guest.completion.support;
const copy = @import("mirai").user.copy.transfer;
const events = @import("tests").fixtures.constants.service;
const harness = @import("tests").guest.postman.harness;
const identities = @import("tests").fixtures.strings.weaver;
const inputs = @import("tests").fixtures.constants.weaver;
const kata = @import("mirai").kata;
const letters = @import("shared").launch.constants.service.postman;
const locations = @import("tests").guest.constants.postman.transport;
const outcomes = @import("tests").guest.constants.completion.outcomes;
const request = @import("shared").launch.service.request;

const Call = @import("shared").persona.types.call.Call;

fn rejected(server: u64, missing: bool) !bool {
    var client = try harness.create();
    defer harness.dispose(client.ID);
    var message: [locations.OUTPUT_BYTES]u8 = undefined;
    const payload = if (missing) request.encode(&message, identities.MISSING_INSTALLED, &.{}) orelse return false else message[0..0];
    try harness.input(&client, payload);
    try harness.descriptorFor(&client, server, letters.LAUNCH, payload.len, 0);
    try harness.install(&client, &.{harness.call(&client)});
    const before = population();
    try harness.start(&client);
    try harness.waitTimedStep(&client, 1, events.TIMEOUT_TICKS);
    const header = try harness.header(&client);
    const accepted = try harness.resultIs(&client, 1, .Success, 0) and header.Sender == server and
        header.Type == (if (missing) letters.MISSING else letters.REFUSED) and header.Length == 0 and
        header.ReplyTicket == 0 and population() == before;
    try harness.advance(&client, 1);
    return accepted;
}

fn population() usize {
    var count: usize = 0;
    var current = kata.state.first();
    while (current) |owner| : (current = kata.state.next(owner)) count += 1;
    return count;
}

pub fn prove(server: u64) !bool {
    if (!try rejected(server, false) or !try rejected(server, true)) return false;
    var client = try harness.create();
    defer harness.dispose(client.ID);
    var message: [locations.OUTPUT_BYTES]u8 = undefined;
    const payload = request.encode(&message, identities.INSTALLED_IDENTITY, &inputs.INSTALLED_PARAMETERS) orelse return false;
    try harness.input(&client, payload);
    const descriptor: Call = .{
        .Destination = server,
        .Type = letters.LAUNCH,
        .Request = client.Data + locations.INPUT_OFFSET,
        .RequestLength = payload.len,
        .Reply = client.Data + locations.TICKET_OFFSET,
        .ReplyCapacity = @sizeOf(u64),
        .Metadata = client.Data + locations.HEADER_OFFSET,
    };
    try copy.write(client.Owner, client.Data + locations.CALL_OFFSET, std.mem.asBytes(&descriptor));
    var wait = completion.operation(&client, outcomes.WAIT);
    wait.First = .{ .Indirect = descriptor.Reply };
    var collect = completion.operation(&client, outcomes.COLLECT);
    collect.First = wait.First;
    try harness.install(&client, &.{ harness.call(&client), wait, collect });
    try harness.start(&client);
    try harness.waitTimedStep(&client, 1, events.TIMEOUT_TICKS);
    const header = try harness.header(&client);
    if (!try harness.resultIs(&client, 1, .Success, @sizeOf(u64)) or header.Sender != server or header.Type != letters.STARTED or
        header.Length != @sizeOf(u64) or header.ReplyTicket != 0) return false;
    var child: u64 = 0;
    try copy.read(client.Owner, std.mem.asBytes(&child), descriptor.Reply);
    if (child == 0) return false;
    defer completion.dispose(child);
    if (kata.completion.storage.ownerOf(child) != client.ID) return false;
    try harness.advance(&client, 1);
    try harness.waitTimedStep(&client, 2, events.TIMEOUT_TICKS);
    const outcome = try completion.record(&client);
    if (!try harness.resultIs(&client, 2, .Success, outcomes.RECORD_BYTES) or outcome.Kind != outcomes.EXITED or
        outcome.Result != inputs.EXPECTED_RESULT) return false;
    try harness.advance(&client, 2);
    try harness.waitStep(&client, 3);
    const collected = try completion.record(&client);
    try harness.advance(&client, 3);
    return try harness.resultIs(&client, 3, .Success, outcomes.RECORD_BYTES) and std.meta.eql(outcome, collected) and
        kata.completion.storage.ownerOf(child) == null;
}
