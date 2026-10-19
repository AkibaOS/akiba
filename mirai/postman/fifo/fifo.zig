//! Incoming Envelope Ordering

const messages = @import("mirai").postman.strings.invariants;

const Envelope = @import("mirai").postman.types.envelope.Envelope;
const Mailbox = @import("mirai").postman.types.mailbox.Mailbox;

pub fn append(mailbox: *Mailbox, envelope: *Envelope) void {
    if (envelope.Next != null or envelope.Destination != mailbox) @panic(messages.INVALID_ENVELOPE);
    if (mailbox.Tail) |tail| {
        tail.Next = envelope;
    } else {
        mailbox.Head = envelope;
    }
    mailbox.Tail = envelope;
    mailbox.Queued += 1;
}

pub fn remove(mailbox: *Mailbox, envelope: *Envelope) void {
    var previous: ?*Envelope = null;
    var current = mailbox.Head;
    while (current) |candidate| {
        if (candidate == envelope) break;
        previous = candidate;
        current = candidate.Next;
    }
    if (current == null or mailbox.Queued == 0) @panic(messages.INVALID_MAILBOX);
    if (previous) |prior| {
        prior.Next = envelope.Next;
    } else {
        mailbox.Head = envelope.Next;
    }
    if (mailbox.Tail == envelope) mailbox.Tail = previous;
    mailbox.Queued -= 1;
    envelope.Next = null;
}
