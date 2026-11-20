//! Phase Ticket Wire Fields

pub const READY = [_]u8{ 0xa7, 0xb1, 'A', 'K', 'P', 'R' };
pub const OFFER = [_]u8{ 'A', 'K', 'P', 'T' };
pub const ACKNOWLEDGEMENT = [_]u8{ 'A', 'K', 'P', 'A' };
pub const EPOCH_OFFSET = OFFER.len;
pub const SCENARIO_OFFSET = EPOCH_OFFSET + @sizeOf(u64);
pub const FRAME_BYTES = SCENARIO_OFFSET + @sizeOf(u8);

pub const STANDARD: u8 = 1;
pub const PULSE_DEATH: u8 = 2;
pub const DEVICES: u8 = 3;
pub const COLLAPSE: u8 = 4;
