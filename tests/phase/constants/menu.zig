//! Firmware Menu Handshake Layout

const date = @import("tests").phase.constants.date;
const Scenario = @import("tests").phase.types.scenario.Scenario;
const Work = @import("tests").phase.types.work.Work;

pub const READY = [_]u8{ 0xa7, 0xb1, 'A', 'K', 'M', 'R' };
pub const OFFER = [_]u8{ 'A', 'K', 'M', 'V' };
pub const ARMED = [_]u8{ 'A', 'K', 'M', 'E' };
pub const COUNTDOWN = [_]u8{ 'A', 'K', 'M', 'C' };
pub const COUNTDOWN_SECONDS: u8 = 30;
pub const EPOCH_OFFSET = OFFER.len;
pub const PASSED_OFFSET = EPOCH_OFFSET + @sizeOf(u64);
pub const DATE_OFFSET = PASSED_OFFSET + @sizeOf(u32);
pub const FAILED_OFFSET = DATE_OFFSET + date.DATE_BYTES;
pub const INTERRUPTED_OFFSET = FAILED_OFFSET + @sizeOf(u8);
pub const STANDARD_OFFSET = INTERRUPTED_OFFSET + @sizeOf(u8);
pub const WORK_OFFSET = STANDARD_OFFSET + @sizeOf(u16);
pub const OFFER_BYTES = WORK_OFFSET + Work.BYTES;
pub const ARMED_BYTES = PASSED_OFFSET;
pub const COUNTDOWN_BYTES = ARMED_BYTES + @sizeOf(u8);
pub const PHASE_COUNT = @typeInfo(Scenario).@"enum".fields.len;
pub const PHASE_MASK: u8 = @intCast((@as(u16, 1) << PHASE_COUNT) - 1);
