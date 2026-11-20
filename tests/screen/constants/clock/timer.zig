//! ACPI Power-Management Timer Geometry

const std = @import("std");

const frame = @import("tests").screen.constants.frame;

pub const FREQUENCY: u32 = 3_579_545;
pub const COUNTER_MASK: u32 = 0x00ff_ffff;
pub const FRAME_TICKS: u32 = @intCast(@as(u64, FREQUENCY) * frame.ANIMATION_MILLISECONDS / std.time.ms_per_s);
