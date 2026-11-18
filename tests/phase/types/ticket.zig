//! Test Only Per Boot Phase Identity

const Scenario = @import("tests").types.scenario.Scenario;
const wire = @import("tests").phase.constants.wire;

pub const Ticket = struct {
    Epoch: u64,
    Scenario: Scenario,
};

pub const Role = enum { Offer, Acknowledgement };
pub const Frame = [wire.FRAME_BYTES]u8;
