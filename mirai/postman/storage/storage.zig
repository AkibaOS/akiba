//! Demand Backed Envelope Storage And Owner Charges

const guard = @import("asm").interrupts.guard;
const labels = @import("mirai").postman.strings.storage;
const limits = @import("mirai").postman.constants.limits;
const memory = @import("mirai").memory;
const messages = @import("mirai").postman.strings.invariants;
const pmm = @import("mirai").pmm;

const Envelope = @import("mirai").postman.types.envelope.Envelope;
const EnvelopeStore = memory.types.pool.store.create(Envelope);
const Mailbox = @import("mirai").postman.types.mailbox.Mailbox;
const PostError = @import("mirai").postman.errors.transport.PostError;
const Status = @import("mirai").postman.types.status.Status;
const Zone = memory.types.zone.Zone;

var records: EnvelopeStore = .{};
var payloads: ?*Zone = null;

pub fn initialize() bool {
    const flags = guard.acquire();
    defer guard.release(flags);
    if (payloads != null) return true;
    records.init(labels.ENVELOPES) catch return false;
    payloads = memory.zone.create.create(labels.PAYLOADS, limits.MAX_PAYLOAD_BYTES) catch {
        if (!records.deinit()) @panic(messages.INVALID_ENVELOPE);
        return false;
    };
    return true;
}

pub fn count() usize {
    const flags = guard.acquire();
    defer guard.release(flags);
    return records.Count;
}

pub fn owns(envelope: *const Envelope) bool {
    return records.owns(envelope);
}

pub fn reserve(source: *Mailbox, destination: *Mailbox, status: Status, letter_type: u64, payload: []const u8) PostError!*Envelope {
    const flags = guard.acquire();
    defer guard.release(flags);
    if (destination.Closed) return PostError.Closed;
    if (payload.len > limits.MAX_PAYLOAD_BYTES) return PostError.TooLarge;
    if (status != .OneWay and status != .Queued) return PostError.InvalidState;
    if (destination.Queued >= limits.MAX_QUEUED_LETTERS or destination.Held >= limits.MAX_HELD_LETTERS or
        source.Outgoing >= limits.MAX_OUTGOING_LETTERS) return PostError.Full;
    const zone = payloads orelse return PostError.NotInitialized;
    const search = pmm.state.getState().SearchStart;
    errdefer pmm.state.getState().SearchStart = search;
    const envelope = records.reserve() catch return PostError.NoResources;
    errdefer discard(envelope);
    const allocation = memory.zone.alloc.zallocZeroed(zone) catch return PostError.NoResources;
    const bytes: *[limits.MAX_PAYLOAD_BYTES]u8 = @ptrCast(allocation);
    envelope.* = .{
        .Status = status,
        .Source = source,
        .Destination = destination,
        .Header = .{ .Sender = source.ID, .Type = letter_type, .Length = payload.len, .ReplyTicket = 0 },
        .Payload = bytes,
        .SourceNext = source.OutgoingHead,
        .HeldNext = destination.HeldHead,
    };
    @memcpy(bytes[0..payload.len], payload);
    if (source.OutgoingHead) |head| head.SourcePrevious = envelope;
    if (destination.HeldHead) |head| head.HeldPrevious = envelope;
    source.OutgoingHead = envelope;
    destination.HeldHead = envelope;
    source.Outgoing += 1;
    destination.Held += 1;
    return envelope;
}

pub fn detachSource(envelope: *Envelope) void {
    const source = envelope.Source orelse return;
    if (source.Outgoing == 0 or
        (if (envelope.SourcePrevious) |previous| previous.SourceNext != envelope else source.OutgoingHead != envelope) or
        (if (envelope.SourceNext) |following| following.SourcePrevious != envelope else false)) @panic(messages.INVALID_ENVELOPE);
    if (envelope.SourcePrevious) |previous| previous.SourceNext = envelope.SourceNext else source.OutgoingHead = envelope.SourceNext;
    if (envelope.SourceNext) |following| following.SourcePrevious = envelope.SourcePrevious;
    source.Outgoing -= 1;
    envelope.Source = null;
    envelope.SourcePrevious = null;
    envelope.SourceNext = null;
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
        if (receiver.Serving != envelope) @panic(messages.INVALID_RECORD);
        receiver.Serving = null;
    }
    envelope.Receiver = null;
    envelope.Ticket = 0;
}

pub fn detachDestination(envelope: *Envelope) void {
    const destination = envelope.Destination orelse return;
    if (destination.Held == 0 or
        (if (envelope.HeldPrevious) |previous| previous.HeldNext != envelope else destination.HeldHead != envelope) or
        (if (envelope.HeldNext) |following| following.HeldPrevious != envelope else false)) @panic(messages.INVALID_ENVELOPE);
    if (envelope.HeldPrevious) |previous| previous.HeldNext = envelope.HeldNext else destination.HeldHead = envelope.HeldNext;
    if (envelope.HeldNext) |following| following.HeldPrevious = envelope.HeldPrevious;
    destination.Held -= 1;
    envelope.Destination = null;
    envelope.HeldPrevious = null;
    envelope.HeldNext = null;
}

pub fn release(envelope: *Envelope) void {
    const flags = guard.acquire();
    defer guard.release(flags);
    if (!records.owns(envelope)) return;
    if (envelope.Queued or envelope.Next != null or envelope.Previous != null) @panic(messages.INVALID_ENVELOPE);
    const zone = payloads orelse @panic(messages.INVALID_ENVELOPE);
    if (!memory.zone.alloc.owns(zone, @ptrCast(envelope.Payload))) @panic(messages.INVALID_ENVELOPE);
    detachClient(envelope);
    detachReceiver(envelope);
    detachDestination(envelope);
    const payload = envelope.Payload;
    memory.zone.alloc.zfree(zone, @ptrCast(payload));
    _ = memory.zone.gc.collectPage(zone, @ptrCast(payload));
    discard(envelope);
}

fn discard(envelope: *Envelope) void {
    if (!records.release(envelope)) @panic(messages.INVALID_ENVELOPE);
    _ = records.collectAt(envelope);
}
