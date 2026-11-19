//! Firmware Menu Handshake Layout

const frame = @import("tests").screen.constants.frame;
const Scenario = @import("tests").types.scenario.Scenario;

pub const READY = [_]u8{ 0xa7, 0xb1, 'A', 'K', 'M', 'R' };
pub const OFFER = [_]u8{ 'A', 'K', 'M', 'S' };
pub const ARMED = [_]u8{ 'A', 'K', 'M', 'E' };
pub const EPOCH_OFFSET = OFFER.len;
pub const PASSED_OFFSET = EPOCH_OFFSET + @sizeOf(u64);
pub const DATE_OFFSET = PASSED_OFFSET + @sizeOf(u32);
pub const FAILED_OFFSET = DATE_OFFSET + frame.DATE_BYTES;
pub const INTERRUPTED_OFFSET = FAILED_OFFSET + @sizeOf(u8);
pub const OFFER_BYTES = INTERRUPTED_OFFSET + @sizeOf(u8);
pub const ARMED_BYTES = PASSED_OFFSET;
pub const PHASE_COUNT = @typeInfo(Scenario).@"enum".fields.len;
