//! Postman Transport State

const limits = @import("mirai").postman.constants.limits;

const Envelope = @import("mirai").postman.types.envelope.Envelope;

pub const State = struct {
    Envelopes: [limits.MAX_ENVELOPES]Envelope = [_]Envelope{.{}} ** limits.MAX_ENVELOPES,
    NextTicket: u64 = 1,
    Initialized: bool = false,
};
