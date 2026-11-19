//! Typed Live Diagnostic View State

const frame = @import("tests").screen.constants.frame;
const wire = @import("tests").phase.constants.live;
const Ticket = @import("tests").phase.types.ticket.Ticket;

pub const Offer = struct {
    Ticket: Ticket,
    Date: [frame.DATE_BYTES]u8,
    FailedMask: u8 = 0,
    InterruptedMask: u8 = 0,
    StandardCompleted: u16 = 0,
    VerifiedChecks: u32 = 0,
};

pub const OfferFrame = [wire.OFFER_BYTES]u8;
pub const Acknowledgement = [wire.ACKNOWLEDGEMENT_BYTES]u8;
