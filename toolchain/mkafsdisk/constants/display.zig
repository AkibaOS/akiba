//! Disk Packing Display Bounds

const std = @import("std");

pub const REFRESH_NS = 40 * std.time.ns_per_ms;
pub const PROGRESS_BYTES = 320;
pub const REPORT_BYTES = 768;
pub const MIB_BYTES = 1 << 20;
