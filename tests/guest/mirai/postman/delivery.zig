//! Persona Send Copy FIFO And Queue Capacity Regressions

const constants = @import("tests").constants.postman;
const harness = @import("tests").guest.mirai.postman.harness;
const labels = @import("tests").strings.postman;
const postman = @import("mirai").postman;
const types = @import("tests").types.postman;
const verify = @import("tests").guest.support.verify;

const Operation = types.Operation;

pub fn run() !void {
    try copiedLetters();
    try queueCapacity();
}

fn copiedLetters() !void {
    var receiver = try harness.create();
    defer harness.dispose(receiver.ID);
    var sender = try harness.create();
    defer harness.dispose(sender.ID);
    try harness.install(&receiver, &.{
        .{ .Service = .Yield },
        harness.receive(&receiver, constants.OUTPUT_BYTES),
        harness.receive(&receiver, constants.OUTPUT_BYTES),
        harness.receive(&receiver, 0),
    });
    var invalid = harness.send(&sender, receiver.ID, constants.LETTER_TYPE, constants.REQUEST.len);
    invalid.Second = constants.INVALID_ADDRESS;
    try harness.install(&sender, &.{
        harness.send(&sender, receiver.ID, constants.LETTER_TYPE, constants.REQUEST.len),
        harness.send(&sender, receiver.ID, constants.SECOND_TYPE, constants.REPLACEMENT.len),
        harness.send(&sender, receiver.ID, constants.LETTER_TYPE, 0),
        harness.send(&sender, constants.INVALID_PEER, constants.LETTER_TYPE, constants.REQUEST.len),
        harness.send(&sender, receiver.ID, constants.LETTER_TYPE, postman.constants.limits.MAX_PAYLOAD_BYTES + 1),
        invalid,
    });
    try harness.start(&receiver);
    try harness.waitStep(&receiver, 1);
    try harness.start(&sender);
    try harness.waitStep(&sender, 1);
    try harness.check(try harness.resultIs(&sender, 1, .Success, 0));
    try harness.input(&sender, &constants.REPLACEMENT);
    try harness.advance(&sender, 1);
    try harness.waitStep(&sender, 2);
    const source = try harness.mailbox(&sender);
    const destination = try harness.mailbox(&receiver);
    try harness.check(source.Outgoing == 2 and destination.Held == 2 and destination.Queued == 2);
    try harness.advance(&receiver, 1);
    try harness.waitStep(&receiver, 2);
    const first = try harness.header(&receiver);
    const copied = try harness.payloadIs(&receiver, &constants.REQUEST);
    try harness.check(source.Outgoing == 1 and destination.Held == 1 and destination.Queued == 1);
    try harness.advance(&receiver, 2);
    try harness.waitStep(&receiver, 3);
    const second = try harness.header(&receiver);
    verify.require(copied and (try harness.payloadIs(&receiver, &constants.REPLACEMENT)) and
        (try harness.resultIs(&receiver, 2, .Success, constants.REQUEST.len)) and
        (try harness.resultIs(&receiver, 3, .Success, constants.REPLACEMENT.len)) and
        first.Sender == sender.ID and first.Type == constants.LETTER_TYPE and first.Length == constants.REQUEST.len and first.ReplyTicket == 0 and
        second.Sender == sender.ID and second.Type == constants.SECOND_TYPE and second.ReplyTicket == 0 and
        source.Outgoing == 0 and destination.Held == 0 and destination.Queued == 0, labels.COPIED_FIFO);
    try harness.advance(&sender, 2);
    try harness.waitStep(&sender, 3);
    try harness.advance(&receiver, 3);
    try harness.waitStep(&receiver, 4);
    const empty = try harness.header(&receiver);
    verify.require((try harness.resultIs(&sender, 3, .Success, 0)) and
        (try harness.resultIs(&receiver, 4, .Success, 0)) and empty.Length == 0 and empty.ReplyTicket == 0 and
        source.Outgoing == 0 and destination.Held == 0 and destination.Queued == 0, labels.EMPTY_LETTER);
    try harness.advance(&sender, 3);
    try harness.waitStep(&sender, 4);
    try harness.advance(&sender, 4);
    try harness.waitStep(&sender, 5);
    try harness.advance(&sender, 5);
    try harness.waitStep(&sender, 6);
    verify.require((try harness.resultIs(&sender, 4, .InvalidPeer, 0)) and
        (try harness.resultIs(&sender, 5, .TooLarge, 0)) and (try harness.resultIs(&sender, 6, .InvalidAddress, 0)) and
        source.Outgoing == 0 and destination.Held == 0 and destination.Queued == 0, labels.SEND_REJECTIONS);
}

fn queueCapacity() !void {
    var receiver = try harness.create();
    defer harness.dispose(receiver.ID);
    var sender = try harness.create();
    defer harness.dispose(sender.ID);
    try harness.install(&receiver, &.{ .{ .Service = .Yield }, harness.receive(&receiver, constants.OUTPUT_BYTES) });
    const limit = postman.constants.limits.MAX_QUEUED_LETTERS;
    var sends: [limit + 2]Operation = undefined;
    for (&sends) |*operation| operation.* = harness.send(&sender, receiver.ID, constants.LETTER_TYPE, constants.REQUEST.len);
    try harness.install(&sender, &sends);
    try harness.start(&receiver);
    try harness.waitStep(&receiver, 1);
    try harness.start(&sender);
    for (1..limit + 2) |step| {
        try harness.waitStep(&sender, step);
        if (step <= limit) {
            try harness.check(try harness.resultIs(&sender, step, .Success, 0));
            try harness.advance(&sender, step);
        }
    }
    const rejected = try harness.resultIs(&sender, limit + 1, .Full, 0);
    const source = try harness.mailbox(&sender);
    const destination = try harness.mailbox(&receiver);
    try harness.check(source.Outgoing == limit and destination.Held == limit and destination.Queued == limit);
    try harness.advance(&receiver, 1);
    try harness.waitStep(&receiver, 2);
    try harness.check(source.Outgoing == limit - 1 and destination.Queued == limit - 1);
    try harness.advance(&sender, limit + 1);
    try harness.waitStep(&sender, limit + 2);
    verify.require(rejected and (try harness.resultIs(&sender, limit + 2, .Success, 0)) and
        source.Outgoing == limit and destination.Held == limit and destination.Queued == limit, labels.QUEUE_CAPACITY);
}
