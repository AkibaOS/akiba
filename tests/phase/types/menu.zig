//! Verified Diagnostic Menu Summary

const frame = @import("tests").screen.constants.frame;
const limits = @import("tests").phase.constants.menu;

pub const Offer = struct {
    Epoch: u64,
    Passed: u32,
    Date: [frame.DATE_BYTES]u8,
    FailedMask: u8 = 0,
    InterruptedMask: u8 = 0,
    StandardCompleted: u16,
};

pub const PhaseStatus = enum { Passed, Failed, Incomplete };

pub const OfferFrame = [limits.OFFER_BYTES]u8;
pub const ArmedFrame = [limits.ARMED_BYTES]u8;
