//! Live Diagnostic Boot Context And Scheduled Progress Units

const date = @import("tests").phase.constants.date;
const menu = @import("tests").phase.constants.menu;
const schedule = @import("tests").phase.strings.schedule;
const Work = @import("tests").phase.types.work.Work;

pub const READY = [_]u8{ 0xa7, 0xb1, 'A', 'K', 'L', 'R' };
pub const OFFER = [_]u8{ 'A', 'K', 'L', 'P' };
pub const ACKNOWLEDGEMENT = [_]u8{ 'A', 'K', 'L', 'A' };
pub const EPOCH_OFFSET = OFFER.len;
pub const SCENARIO_OFFSET = EPOCH_OFFSET + @sizeOf(u64);
pub const ACKNOWLEDGEMENT_BYTES = SCENARIO_OFFSET + @sizeOf(u8);
pub const FAILED_OFFSET = ACKNOWLEDGEMENT_BYTES;
pub const INTERRUPTED_OFFSET = FAILED_OFFSET + @sizeOf(u8);
pub const STANDARD_OFFSET = INTERRUPTED_OFFSET + @sizeOf(u8);
pub const CHECKS_OFFSET = STANDARD_OFFSET + @sizeOf(u16);
pub const DATE_OFFSET = CHECKS_OFFSET + @sizeOf(u32);
pub const WORK_OFFSET = DATE_OFFSET + date.DATE_BYTES;
pub const OFFER_BYTES = WORK_OFFSET + Work.BYTES;

pub const STANDARD_UNITS: u16 = schedule.GROUPS.len + 1;
pub const TOTAL_UNITS: usize = STANDARD_UNITS + menu.PHASE_COUNT - 1;
