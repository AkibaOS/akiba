//! Incoming Letter Copy And Acceptance

const fifo = @import("mirai").postman.fifo;
const guard = @import("asm").interrupts.guard;
const inbox = @import("mirai").postman.inbox;
const record = @import("mirai").postman.record;
const state = @import("mirai").postman.state;
const storage = @import("mirai").postman.storage;
const ticket = @import("mirai").postman.ticket;
const validate = @import("mirai").postman.validate;

const PostError = @import("mirai").postman.errors.transport.PostError;
const Queue = @import("mirai").sensei.types.queue.Queue;
const Thread = @import("mirai").thread.types.thread.Thread;
const View = @import("mirai").postman.types.letter.View;

pub fn queue(receiver: *Thread) PostError!*Queue {
    const previous_flags = guard.acquire();
    defer guard.release(previous_flags);
    try validate.current(receiver);
    const entry = try record.get(receiver);
    if (entry.Serving != null) return PostError.Busy;
    const mailbox = try inbox.get(receiver.Owner);
    if (mailbox.Closed) return PostError.Closed;
    return &mailbox.Receivers;
}

pub fn ready(context: ?*anyopaque) bool {
    const previous_flags = guard.acquire();
    defer guard.release(previous_flags);
    if (!state.getState().Initialized) return true;
    const raw_context = context orelse return true;
    const receiver: *Thread = @ptrCast(@alignCast(raw_context));
    if (!validate.live(receiver)) return true;
    const entry = record.find(receiver) orelse return true;
    if (entry.Serving != null) return true;
    const mailbox = inbox.find(receiver.Owner) orelse return true;
    return mailbox.Closed or mailbox.Head != null;
}

pub fn peek(receiver: *Thread) PostError!View {
    const previous_flags = guard.acquire();
    defer guard.release(previous_flags);
    try validate.current(receiver);
    const entry = try record.get(receiver);
    if (entry.Serving != null) return PostError.Busy;
    const mailbox = try inbox.get(receiver.Owner);
    if (mailbox.Closed) return PostError.Closed;
    const envelope = mailbox.Head orelse return PostError.WouldBlock;
    var header = envelope.Header;
    switch (envelope.Status) {
        .OneWay => {},
        .Queued => header.ReplyTicket = try ticket.reserve(envelope),
        .Free, .Delivered, .Replied, .Returned => return PostError.InvalidState,
    }
    return .{
        .Header = header,
        .Payload = envelope.Payload[0..@intCast(envelope.Header.Length)],
    };
}

pub fn consume(receiver: *Thread) PostError!void {
    const previous_flags = guard.acquire();
    defer guard.release(previous_flags);
    try validate.current(receiver);
    const entry = record.find(receiver) orelse return PostError.InvalidState;
    if (entry.Serving != null) return PostError.Busy;
    const mailbox = inbox.find(receiver.Owner) orelse return PostError.InvalidState;
    if (mailbox.Closed) return PostError.Closed;
    const envelope = mailbox.Head orelse return PostError.WouldBlock;
    switch (envelope.Status) {
        .OneWay => {
            fifo.remove(mailbox, envelope);
            storage.release(envelope);
        },
        .Queued => {
            if (envelope.Ticket == 0 or envelope.Client == null) return PostError.InvalidState;
            fifo.remove(mailbox, envelope);
            envelope.Receiver = entry;
            envelope.Status = .Delivered;
            entry.Serving = envelope;
        },
        .Free, .Delivered, .Replied, .Returned => return PostError.InvalidState,
    }
}
