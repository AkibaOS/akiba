//! Intrusive Incoming Envelope Ordering

const messages = @import("mirai").postman.strings.invariants;
const storage = @import("mirai").postman.storage;

const Envelope = @import("mirai").postman.types.envelope.Envelope;
const Mailbox = @import("mirai").postman.types.mailbox.Mailbox;

pub fn append(mailbox: *Mailbox, envelope: *Envelope) void {
    if (!storage.owns(envelope)) @panic(messages.INVALID_ENVELOPE);
    if (envelope.Queued or envelope.Next != null or envelope.Previous != null or envelope.Destination != mailbox)
        @panic(messages.INVALID_ENVELOPE);
    envelope.Previous = mailbox.Tail;
    if (mailbox.Tail) |tail| tail.Next = envelope else mailbox.Head = envelope;
    mailbox.Tail = envelope;
    mailbox.Queued += 1;
    envelope.Queued = true;
}

pub fn remove(mailbox: *Mailbox, envelope: *Envelope) void {
    if (!storage.owns(envelope)) @panic(messages.INVALID_ENVELOPE);
    if (!envelope.Queued or envelope.Destination != mailbox or mailbox.Queued == 0 or
        (if (envelope.Previous) |previous| previous.Next != envelope else mailbox.Head != envelope) or
        (if (envelope.Next) |following| following.Previous != envelope else mailbox.Tail != envelope)) @panic(messages.INVALID_MAILBOX);
    if (envelope.Previous) |previous| previous.Next = envelope.Next else mailbox.Head = envelope.Next;
    if (envelope.Next) |following| following.Previous = envelope.Previous else mailbox.Tail = envelope.Previous;
    mailbox.Queued -= 1;
    envelope.Next = null;
    envelope.Previous = null;
    envelope.Queued = false;
}
