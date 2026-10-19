//! Bound One Shot Reply Delivery

const guard = @import("asm").interrupts.guard;
const notification = @import("mirai").postman.notification;
const record = @import("mirai").postman.record;
const storage = @import("mirai").postman.storage;
const validate = @import("mirai").postman.validate;

const PostError = @import("mirai").postman.errors.transport.PostError;
const Thread = @import("mirai").thread.types.thread.Thread;

pub fn send(server: *Thread, reply_ticket: u64, letter_type: u64, payload: []const u8) PostError!void {
    const previous_flags = guard.acquire();
    defer guard.release(previous_flags);
    try validate.current(server);
    const entry = record.find(server) orelse return PostError.InvalidReply;
    const envelope = entry.Serving orelse return PostError.InvalidReply;
    if (reply_ticket == 0 or envelope.Ticket != reply_ticket or envelope.Receiver != entry or
        envelope.Status != .Delivered) return PostError.InvalidReply;
    const client = envelope.Client orelse {
        storage.release(envelope);
        return PostError.PeerGone;
    };
    const target = client.Thread orelse {
        storage.release(envelope);
        return PostError.PeerGone;
    };
    if (!validate.live(target)) {
        storage.release(envelope);
        return PostError.PeerGone;
    }
    try validate.payload(payload);
    @memcpy(envelope.Payload[0..payload.len], payload);
    envelope.Header = .{ .Sender = server.Owner.ID, .Type = letter_type, .Length = payload.len, .ReplyTicket = 0 };
    storage.detachReceiver(envelope);
    envelope.Status = .Replied;
    notification.caller(client);
}
