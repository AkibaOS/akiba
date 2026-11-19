//! Persona Postman Peer And Caller Shutdown Regressions

const constants = @import("tests").constants.postman;
const harness = @import("tests").guest.mirai.postman.harness;
const labels = @import("tests").strings.postman;
const postman = @import("mirai").postman;
const types = @import("tests").guest.types.postman;
const verify = @import("tests").guest.support.verify;

const FixtureError = types.FixtureError;
const Pair = types.Pair;
const Status = postman.types.status.Status;

pub fn run() !void {
    try peerQueued();
    try peerDelivered();
    try peerReplied();
    try callerQueued();
    try callerDelivered();
    try callerReplied();
    try oneWaySender();
}

fn prepare(phase: Status) !Pair {
    var pair: Pair = .{ .Peer = try harness.create(), .Client = undefined };
    errdefer harness.dispose(pair.Peer.ID);
    pair.Client = try harness.create();
    errdefer harness.dispose(pair.Client.ID);
    try harness.input(&pair.Peer, &constants.REPLY);
    try harness.descriptor(&pair.Client, pair.Peer.ID, if (phase == .Replied) 0 else constants.OUTPUT_BYTES);
    switch (phase) {
        .Queued => try harness.install(&pair.Peer, &.{.{ .Service = .Yield }}),
        .Delivered, .Replied => try harness.install(&pair.Peer, &.{
            harness.receive(&pair.Peer, constants.OUTPUT_BYTES), harness.reply(&pair.Peer),
        }),
        else => return FixtureError.InvalidFixture,
    }
    try harness.install(&pair.Client, &.{ harness.call(&pair.Client), harness.collect(&pair.Client, constants.OUTPUT_BYTES) });
    try harness.start(&pair.Peer);
    if (phase == .Queued) try harness.waitStep(&pair.Peer, 1) else try harness.waitBlocked(&pair.Peer);
    try harness.start(&pair.Client);
    if (phase == .Queued) {
        try harness.waitBlocked(&pair.Client);
    } else {
        try harness.waitStep(&pair.Peer, 1);
        try harness.waitBlocked(&pair.Client);
    }
    if (phase == .Replied) {
        try harness.advance(&pair.Peer, 1);
        try harness.waitStep(&pair.Peer, 2);
        try harness.waitStep(&pair.Client, 1);
        try harness.check(try harness.resultIs(&pair.Client, 1, .BufferTooSmall, constants.REPLY.len));
    }
    const pending = (try harness.record(&pair.Client)).Pending orelse return FixtureError.InvalidFixture;
    try harness.check(pending.Status == phase);
    return pair;
}

fn peerQueued() !void {
    const pair = try prepare(.Queued);
    defer harness.dispose(pair.Peer.ID);
    defer harness.dispose(pair.Client.ID);
    const source = try harness.mailbox(&pair.Client);
    const record = try harness.record(&pair.Client);
    try harness.check((try harness.mailbox(&pair.Peer)).Queued == 1 and source.Outgoing == 1);
    harness.dispose(pair.Peer.ID);
    try harness.waitStep(&pair.Client, 1);
    verify.require((try harness.resultIs(&pair.Client, 1, .PeerGone, 0)) and record.Pending == null and
        source.Outgoing == 0 and (try harness.untouched(&pair.Client)), labels.PEER_QUEUED);
}

fn peerDelivered() !void {
    const pair = try prepare(.Delivered);
    defer harness.dispose(pair.Peer.ID);
    defer harness.dispose(pair.Client.ID);
    const source = try harness.mailbox(&pair.Client);
    const record = try harness.record(&pair.Client);
    harness.dispose(pair.Peer.ID);
    try harness.waitStep(&pair.Client, 1);
    verify.require((try harness.resultIs(&pair.Client, 1, .PeerGone, 0)) and record.Pending == null and
        source.Outgoing == 0 and (try harness.untouched(&pair.Client)), labels.PEER_DELIVERED);
}

fn peerReplied() !void {
    const pair = try prepare(.Replied);
    defer harness.dispose(pair.Peer.ID);
    defer harness.dispose(pair.Client.ID);
    const source = try harness.mailbox(&pair.Client);
    const record = try harness.record(&pair.Client);
    const pending = record.Pending orelse return FixtureError.InvalidFixture;
    harness.dispose(pair.Peer.ID);
    try harness.check(pending.Status == .Replied and pending.Destination == null and source.Outgoing == 1);
    try harness.advance(&pair.Client, 1);
    try harness.waitStep(&pair.Client, 2);
    const header = try harness.header(&pair.Client);
    verify.require((try harness.resultIs(&pair.Client, 2, .Success, constants.REPLY.len)) and
        (try harness.payloadIs(&pair.Client, &constants.REPLY)) and header.Sender == pair.Peer.ID and
        header.Type == constants.REPLY_TYPE and header.ReplyTicket == 0 and record.Pending == null and
        source.Outgoing == 0, labels.PEER_REPLIED);
}

fn callerQueued() !void {
    const pair = try prepare(.Queued);
    defer harness.dispose(pair.Peer.ID);
    defer harness.dispose(pair.Client.ID);
    const destination = try harness.mailbox(&pair.Peer);
    harness.dispose(pair.Client.ID);
    verify.require(destination.Queued == 0 and destination.Held == 0 and destination.Head == null and destination.Tail == null, labels.CALLER_QUEUED);
}

fn callerDelivered() !void {
    const pair = try prepare(.Delivered);
    defer harness.dispose(pair.Peer.ID);
    defer harness.dispose(pair.Client.ID);
    const destination = try harness.mailbox(&pair.Peer);
    const record = try harness.record(&pair.Peer);
    const serving = record.Serving orelse return FixtureError.InvalidFixture;
    harness.dispose(pair.Client.ID);
    try harness.check(serving.Status == .Delivered and serving.Client == null and serving.Source == null and
        record.Serving == serving and destination.Held == 1);
    try harness.advance(&pair.Peer, 1);
    try harness.waitStep(&pair.Peer, 2);
    verify.require((try harness.resultIs(&pair.Peer, 2, .PeerGone, 0)) and record.Serving == null and
        !postman.storage.owns(serving) and destination.Held == 0 and destination.Queued == 0, labels.CALLER_DELIVERED);
}

fn callerReplied() !void {
    const pair = try prepare(.Replied);
    defer harness.dispose(pair.Peer.ID);
    defer harness.dispose(pair.Client.ID);
    const destination = try harness.mailbox(&pair.Peer);
    const pending = (try harness.record(&pair.Client)).Pending orelse return FixtureError.InvalidFixture;
    try harness.check(destination.Held == 1);
    harness.dispose(pair.Client.ID);
    verify.require(!postman.storage.owns(pending) and destination.Held == 0 and destination.Queued == 0 and
        (try harness.record(&pair.Peer)).Serving == null, labels.CALLER_REPLIED);
}

fn oneWaySender() !void {
    var receiver = try harness.create();
    defer harness.dispose(receiver.ID);
    var sender = try harness.create();
    defer harness.dispose(sender.ID);
    try harness.install(&receiver, &.{ .{ .Service = .Yield }, harness.receive(&receiver, constants.OUTPUT_BYTES) });
    try harness.install(&sender, &.{harness.send(&sender, receiver.ID, constants.LETTER_TYPE, constants.REQUEST.len)});
    try harness.start(&receiver);
    try harness.waitStep(&receiver, 1);
    try harness.start(&sender);
    try harness.waitStep(&sender, 1);
    const destination = try harness.mailbox(&receiver);
    const queued = destination.Head orelse return FixtureError.InvalidFixture;
    harness.dispose(sender.ID);
    try harness.check(queued.Status == .OneWay and queued.Source == null and destination.Held == 1 and destination.Queued == 1);
    try harness.advance(&receiver, 1);
    try harness.waitStep(&receiver, 2);
    const header = try harness.header(&receiver);
    verify.require((try harness.resultIs(&receiver, 2, .Success, constants.REQUEST.len)) and
        (try harness.payloadIs(&receiver, &constants.REQUEST)) and header.Sender == sender.ID and header.ReplyTicket == 0 and
        destination.Held == 0 and destination.Queued == 0, labels.ONEWAY_SURVIVES);
}
