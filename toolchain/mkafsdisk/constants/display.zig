//! Disk Packing Display Bounds

const std = @import("std");

pub const REFRESH_NS = 16 * std.time.ns_per_ms;
pub const SHORT_PACK_UNITS = 16;
pub const PROGRESS_BYTES = 320;
pub const REPORT_BUFFER_BYTES = 1024;
pub const MIB_BYTES = 1 << 20;
