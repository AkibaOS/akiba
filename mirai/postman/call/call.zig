//! Pending Client Calls And Reply Collection

const fifo = @import("mirai").postman.fifo;
const guard = @import("asm").interrupts.guard;
const inbox = @import("mirai").postman.inbox;
const notification = @import("mirai").postman.notification;
const record = @import("mirai").postman.record;
const state = @import("mirai").postman.state;
const storage = @import("mirai").postman.storage;
const ticket = @import("mirai").postman.ticket;
const validate = @import("mirai").postman.validate;

const PostError = @import("mirai").postman.errors.transport.PostError;
const Queue = @import("mirai").sensei.types.queue.Queue;
const Thread = @import("mirai").thread.types.thread.Thread;
const View = @import("mirai").postman.types.letter.View;

pub fn begin(sender: *Thread, destination_id: u64, letter_type: u64, payload: []const u8) PostError!?*Thread {
    const previous_flags = guard.acquire();
    defer guard.release(previous_flags);
    try validate.current(sender);
    try validate.payload(payload);
    const client = try record.get(sender);
    if (client.Pending != null) return PostError.Busy;
    const destination = try inbox.destination(destination_id);
    const source = try inbox.get(sender.Owner);
    const envelope = try storage.reserve(source, destination, .Queued, letter_type, payload);
    errdefer storage.release(envelope);
    _ = try ticket.reserve(envelope);
    envelope.Client = client;
    client.Pending = envelope;
    fifo.append(destination, envelope);
    return notification.receiver(destination);
}

pub fn queue(client: *Thread) PostError!*Queue {
    const previous_flags = guard.acquire();
    defer guard.release(previous_flags);
    try validate.current(client);
    const entry = record.find(client) orelse return PostError.InvalidState;
    if (entry.Pending == null) return PostError.InvalidState;
    return &entry.Callers;
}

pub fn ready(context: ?*anyopaque) bool {
    const previous_flags = guard.acquire();
    defer guard.release(previous_flags);
    if (!state.getState().Initialized) return true;
    const raw_context = context orelse return true;
    const client: *Thread = @ptrCast(@alignCast(raw_context));
    if (!validate.live(client)) return true;
    const entry = record.find(client) orelse return true;
    const pending = entry.Pending orelse return true;
    return pending.Status != .Queued and pending.Status != .Delivered;
}

pub fn peek(client: *Thread) PostError!View {
    const previous_flags = guard.acquire();
    defer guard.release(previous_flags);
    try validate.current(client);
    const entry = record.find(client) orelse return PostError.InvalidState;
    const pending = entry.Pending orelse return PostError.InvalidState;
    switch (pending.Status) {
        .Queued, .Delivered => return PostError.WouldBlock,
        .Replied => return .{
            .Header = pending.Header,
            .Payload = pending.Payload[0..@intCast(pending.Header.Length)],
        },
        .Returned => {
            storage.release(pending);
            return PostError.PeerGone;
        },
        .Free, .OneWay => return PostError.InvalidState,
    }
}

pub fn consume(client: *Thread) PostError!void {
    const previous_flags = guard.acquire();
    defer guard.release(previous_flags);
    try validate.current(client);
    const entry = record.find(client) orelse return PostError.InvalidState;
    const pending = entry.Pending orelse return PostError.InvalidState;
    switch (pending.Status) {
        .Queued, .Delivered => return PostError.WouldBlock,
        .Replied => storage.release(pending),
        .Returned => {
            storage.release(pending);
            return PostError.PeerGone;
        },
        .Free, .OneWay => return PostError.InvalidState,
    }
}
