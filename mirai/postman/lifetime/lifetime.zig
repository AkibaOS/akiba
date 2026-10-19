//! Envelope Cancellation And Mailbox Closure

const fifo = @import("mirai").postman.fifo;
const messages = @import("mirai").postman.strings.invariants;
const notification = @import("mirai").postman.notification;
const record = @import("mirai").postman.record;
const state = @import("mirai").postman.state;
const storage = @import("mirai").postman.storage;

const Envelope = @import("mirai").postman.types.envelope.Envelope;
const Mailbox = @import("mirai").postman.types.mailbox.Mailbox;
const Record = @import("mirai").postman.types.record.Record;

pub fn discardLetter(envelope: *Envelope) void {
    if (envelope.Status != .OneWay) @panic(messages.INVALID_ENVELOPE);
    const destination = envelope.Destination orelse @panic(messages.INVALID_ENVELOPE);
    fifo.remove(destination, envelope);
    storage.release(envelope);
}

pub fn cancelClient(envelope: *Envelope) void {
    switch (envelope.Status) {
        .Free => return,
        .OneWay => discardLetter(envelope),
        .Queued => {
            const destination = envelope.Destination orelse @panic(messages.INVALID_ENVELOPE);
            fifo.remove(destination, envelope);
            storage.release(envelope);
        },
        .Delivered => {
            const receiver = envelope.Receiver orelse @panic(messages.INVALID_ENVELOPE);
            if (receiver.Serving != envelope) @panic(messages.INVALID_RECORD);
            storage.detachClient(envelope);
        },
        .Replied, .Returned => storage.release(envelope),
    }
}

pub fn returnCall(envelope: *Envelope) void {
    switch (envelope.Status) {
        .Queued => {
            const destination = envelope.Destination orelse @panic(messages.INVALID_ENVELOPE);
            fifo.remove(destination, envelope);
        },
        .Delivered => {},
        .Replied, .Returned => {
            storage.detachDestination(envelope);
            return;
        },
        .Free, .OneWay => @panic(messages.INVALID_ENVELOPE),
    }
    storage.detachReceiver(envelope);
    storage.detachDestination(envelope);
    const client = envelope.Client orelse {
        storage.release(envelope);
        return;
    };
    envelope.Status = .Returned;
    envelope.Header = .{ .Sender = 0, .Type = 0, .Length = 0, .ReplyTicket = 0 };
    notification.caller(client);
}

pub fn close(mailbox: *Mailbox) void {
    if (mailbox.Closed) return;
    mailbox.Closed = true;
    for (&state.getState().Envelopes) |*envelope| {
        if (envelope.Destination != mailbox) continue;
        switch (envelope.Status) {
            .OneWay => discardLetter(envelope),
            .Queued, .Delivered => returnCall(envelope),
            .Replied, .Returned => storage.detachDestination(envelope),
            .Free => @panic(messages.INVALID_ENVELOPE),
        }
    }
    if (mailbox.Head != null or mailbox.Tail != null or mailbox.Queued != 0 or mailbox.Held != 0) {
        @panic(messages.INVALID_MAILBOX);
    }
    notification.receivers(mailbox);
}

pub fn clearRecord(entry: *Record) void {
    if (entry.Pending) |pending| cancelClient(pending);
    if (entry.Serving) |serving| returnCall(serving);
    for (&state.getState().Envelopes) |*envelope| {
        if (envelope.Receiver != entry) continue;
        if (envelope.Status != .OneWay and envelope.Status != .Queued) @panic(messages.INVALID_RECORD);
        envelope.Receiver = null;
    }
    record.release(entry);
}
