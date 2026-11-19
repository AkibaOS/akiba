//! Firmware Menu Handshake Layout

const frame = @import("tests").screen.constants.frame;

pub const READY = [_]u8{ 0xa7, 0xb1, 'A', 'K', 'M', 'R' };
pub const OFFER = [_]u8{ 'A', 'K', 'M', 'S' };
pub const ARMED = [_]u8{ 'A', 'K', 'M', 'E' };
pub const EPOCH_OFFSET = OFFER.len;
pub const PASSED_OFFSET = EPOCH_OFFSET + @sizeOf(u64);
pub const DATE_OFFSET = PASSED_OFFSET + @sizeOf(u32);
pub const OFFER_BYTES = DATE_OFFSET + frame.DATE_BYTES;
pub const ARMED_BYTES = PASSED_OFFSET;
