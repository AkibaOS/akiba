//! Persona Receive Output Safety And Receiver Wake Regressions

const abi = @import("shared").persona.types.invocation;
const constants = @import("tests").guest.constants.postman.transport;
const harness = @import("tests").guest.postman.harness;
const labels = @import("tests").guest.strings.postman.witnesses;
const verify = @import("tests").guest.support.verify;

pub fn run() !void {
    try outputFailures();
    try nextReceiver();
    try closeReceivers();
}

fn outputFailures() !void {
    var receiver = try harness.create();
    defer harness.dispose(receiver.ID);
    var sender = try harness.create();
    defer harness.dispose(sender.ID);
    var invalid_buffer = harness.receive(&receiver, constants.OUTPUT_BYTES);
    invalid_buffer.First = .{ .Immediate = constants.INVALID_ADDRESS };
    var invalid_metadata = harness.receive(&receiver, constants.OUTPUT_BYTES);
    invalid_metadata.Third = constants.INVALID_ADDRESS;
    var overlapping = harness.receive(&receiver, constants.REQUEST.len);
    overlapping.First = .{ .Immediate = receiver.Data + constants.HEADER_OFFSET };
    try harness.install(&receiver, &.{
        .{ .Service = .Yield },                                invalid_buffer,                                     invalid_metadata, overlapping,
        harness.receive(&receiver, constants.REQUEST.len - 1), harness.receive(&receiver, constants.OUTPUT_BYTES),
    });
    try harness.install(&sender, &.{harness.send(&sender, receiver.ID, constants.LETTER_TYPE, constants.REQUEST.len)});
    try harness.start(&receiver);
    try harness.waitStep(&receiver, 1);
    try harness.start(&sender);
    try harness.waitStep(&sender, 1);
    const destination = try harness.mailbox(&receiver);
    const source = try harness.mailbox(&sender);
    const original = destination.Head;
    var preserved = true;
    for (2..6) |step| {
        try harness.advance(&receiver, step - 1);
        try harness.waitStep(&receiver, step);
        const status: abi.Status = if (step == 5) .BufferTooSmall else .InvalidAddress;
        const value: u64 = if (step == 5) constants.REQUEST.len else 0;
        preserved = preserved and (try harness.resultIs(&receiver, step, status, value)) and
            (try harness.untouched(&receiver)) and destination.Head == original and
            destination.Queued == 1 and destination.Held == 1 and source.Outgoing == 1;
    }
    try harness.advance(&receiver, 5);
    try harness.waitStep(&receiver, 6);
    const header = try harness.header(&receiver);
    verify.require(preserved and (try harness.resultIs(&receiver, 6, .Success, constants.REQUEST.len)) and
        (try harness.payloadIs(&receiver, &constants.REQUEST)) and header.Sender == sender.ID and
        header.Type == constants.LETTER_TYPE and header.Length == constants.REQUEST.len and
        source.Outgoing == 0 and destination.Queued == 0 and destination.Held == 0, labels.RECEIVE_NONCONSUMPTION);
}

fn nextReceiver() !void {
    var first = try harness.create();
    defer harness.dispose(first.ID);
    var second = try harness.sibling(&first, 1);
    var sender = try harness.create();
    defer harness.dispose(sender.ID);
    try harness.install(&first, &.{harness.receive(&first, 0)});
    try harness.install(&second, &.{harness.receive(&second, constants.OUTPUT_BYTES)});
    try harness.install(&sender, &.{harness.send(&sender, first.ID, constants.LETTER_TYPE, constants.REQUEST.len)});
    try harness.start(&first);
    try harness.waitBlocked(&first);
    try harness.start(&second);
    try harness.waitBlocked(&second);
    const destination = try harness.mailbox(&first);
    try harness.check(destination.Receivers.Count == 2);
    try harness.start(&sender);
    try harness.waitStep(&first, 1);
    try harness.waitStep(&second, 1);
    try harness.waitStep(&sender, 1);
    const header = try harness.header(&second);
    verify.require((try harness.resultIs(&first, 1, .BufferTooSmall, constants.REQUEST.len)) and
        (try harness.untouched(&first)) and (try harness.resultIs(&second, 1, .Success, constants.REQUEST.len)) and
        (try harness.payloadIs(&second, &constants.REQUEST)) and header.Sender == sender.ID and
        destination.Receivers.Count == 0 and destination.Queued == 0 and destination.Held == 0 and
        (try harness.mailbox(&sender)).Outgoing == 0, labels.RECEIVE_HANDOFF);
}

fn closeReceivers() !void {
    var first = try harness.create();
    defer harness.dispose(first.ID);
    var second = try harness.sibling(&first, 1);
    var closer = try harness.sibling(&first, 2);
    var sender = try harness.create();
    defer harness.dispose(sender.ID);
    try harness.install(&first, &.{ harness.receive(&first, constants.OUTPUT_BYTES), harness.receive(&first, constants.OUTPUT_BYTES) });
    try harness.install(&second, &.{harness.receive(&second, constants.OUTPUT_BYTES)});
    try harness.install(&closer, &.{ .{ .Service = .Close }, .{ .Service = .Close } });
    try harness.install(&sender, &.{harness.send(&sender, first.ID, constants.LETTER_TYPE, constants.REQUEST.len)});
    try harness.start(&first);
    try harness.waitBlocked(&first);
    try harness.start(&second);
    try harness.waitBlocked(&second);
    try harness.start(&closer);
    try harness.waitStep(&closer, 1);
    try harness.waitStep(&first, 1);
    try harness.waitStep(&second, 1);
    try harness.advance(&closer, 1);
    try harness.waitStep(&closer, 2);
    try harness.advance(&first, 1);
    try harness.waitStep(&first, 2);
    try harness.start(&sender);
    try harness.waitStep(&sender, 1);
    const destination = try harness.mailbox(&first);
    verify.require((try harness.resultIs(&closer, 1, .Success, 0)) and
        (try harness.resultIs(&closer, 2, .Success, 0)) and
        (try harness.resultIs(&first, 1, .Closed, 0)) and (try harness.resultIs(&first, 2, .Closed, 0)) and
        (try harness.resultIs(&second, 1, .Closed, 0)) and (try harness.resultIs(&sender, 1, .Closed, 0)) and
        destination.Closed and destination.Receivers.Count == 0 and destination.Queued == 0 and destination.Held == 0, labels.CLOSE_WAKE);
}
