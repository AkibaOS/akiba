//! Typed Live Diagnostic View State

const date = @import("tests").phase.constants.date.format;
const wire = @import("tests").phase.constants.live.frame;
const Ticket = @import("tests").phase.types.ticket.Ticket;
const Tally = @import("tests").phase.types.work.Work;

pub const Offer = struct {
    Ticket: Ticket,
    Date: [date.DATE_BYTES]u8,
    FailedMask: u8 = 0,
    InterruptedMask: u8 = 0,
    StandardCompleted: u16 = 0,
    VerifiedChecks: u32 = 0,
    Work: Tally,
};

pub const OfferFrame = [wire.OFFER_BYTES]u8;
pub const Acknowledgement = [wire.ACKNOWLEDGEMENT_BYTES]u8;
