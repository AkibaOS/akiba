//! One Shot Reply Ticket Reservation

const std = @import("std");

const state = @import("mirai").postman.state;

const Envelope = @import("mirai").postman.types.envelope.Envelope;
const PostError = @import("mirai").postman.errors.transport.PostError;

pub fn reserve(envelope: *Envelope) PostError!u64 {
    if (envelope.Status != .Queued) return PostError.InvalidState;
    if (envelope.Ticket != 0) return envelope.Ticket;
    const transport = state.getState();
    if (transport.NextTicket == std.math.maxInt(u64)) return PostError.NoResources;
    envelope.Ticket = transport.NextTicket;
    transport.NextTicket += 1;
    return envelope.Ticket;
}
