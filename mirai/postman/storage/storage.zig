//! Envelope Pool And Ownership Charges

const limits = @import("mirai").postman.constants.limits;
const messages = @import("mirai").postman.strings.invariants;
const state = @import("mirai").postman.state;

const Envelope = @import("mirai").postman.types.envelope.Envelope;
const Mailbox = @import("mirai").postman.types.mailbox.Mailbox;
const PostError = @import("mirai").postman.errors.transport.PostError;
const Status = @import("mirai").postman.types.status.Status;

pub fn reserve(source: *Mailbox, destination: *Mailbox, status: Status, letter_type: u64, payload: []const u8) PostError!*Envelope {
    if (destination.Closed) return PostError.Closed;
    if (payload.len > limits.MAX_PAYLOAD_BYTES) return PostError.TooLarge;
    if (status != .OneWay and status != .Queued) return PostError.InvalidState;
    if (destination.Queued >= limits.MAX_QUEUED_LETTERS or destination.Held >= limits.MAX_HELD_LETTERS or
        source.Outgoing >= limits.MAX_OUTGOING_LETTERS) return PostError.Full;
    for (&state.getState().Envelopes) |*envelope| {
        if (envelope.Status != .Free) continue;
        envelope.Status = status;
        envelope.Source = source;
        envelope.Destination = destination;
        envelope.Header = .{ .Sender = source.ID, .Type = letter_type, .Length = payload.len, .ReplyTicket = 0 };
        @memcpy(envelope.Payload[0..payload.len], payload);
        source.Outgoing += 1;
        destination.Held += 1;
        return envelope;
    }
    return PostError.NoResources;
}

pub fn detachSource(envelope: *Envelope) void {
    const source = envelope.Source orelse return;
    if (source.Outgoing == 0) @panic(messages.INVALID_ENVELOPE);
    source.Outgoing -= 1;
    envelope.Source = null;
}

pub fn detachClient(envelope: *Envelope) void {
    if (envelope.Client) |client| {
        if (client.Pending != envelope) @panic(messages.INVALID_RECORD);
        client.Pending = null;
        envelope.Client = null;
    }
    detachSource(envelope);
}

pub fn detachReceiver(envelope: *Envelope) void {
    if (envelope.Receiver) |receiver| {
        if (receiver.Serving == envelope) receiver.Serving = null;
    }
    envelope.Receiver = null;
    envelope.Ticket = 0;
}

pub fn detachDestination(envelope: *Envelope) void {
    const destination = envelope.Destination orelse return;
    if (destination.Held == 0) @panic(messages.INVALID_ENVELOPE);
    destination.Held -= 1;
    envelope.Destination = null;
}

pub fn release(envelope: *Envelope) void {
    if (envelope.Status == .Free) return;
    detachClient(envelope);
    detachReceiver(envelope);
    detachDestination(envelope);
    envelope.Next = null;
    envelope.Header = .{ .Sender = 0, .Type = 0, .Length = 0, .ReplyTicket = 0 };
    envelope.Status = .Free;
}
