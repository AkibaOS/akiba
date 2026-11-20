//! Verified Diagnostic Menu Summary

const date = @import("tests").phase.constants.date.format;
const limits = @import("tests").phase.constants.menu.frame;
const Tally = @import("tests").phase.types.work.Work;

pub const Offer = struct {
    Epoch: u64,
    Passed: u32,
    Date: [date.DATE_BYTES]u8,
    FailedMask: u8 = 0,
    InterruptedMask: u8 = 0,
    StandardCompleted: u16,
    Work: Tally,
};

pub const PhaseStatus = enum { Passed, Failed, Incomplete };

pub const OfferFrame = [limits.OFFER_BYTES]u8;
pub const ArmedFrame = [limits.ARMED_BYTES]u8;
pub const CountdownFrame = [limits.COUNTDOWN_BYTES]u8;
