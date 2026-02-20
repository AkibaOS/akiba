//! Date and time utilities

pub const time = @import("time.zig");
pub const fmt = @import("format.zig");
pub const types = @import("types.zig");

pub const now = time.now;
pub const parts = time.parts;

pub const formatDate = fmt.date;
pub const formatDuration = fmt.duration;

pub const DateTime = types.DateTime;
