//! Physical Page Free

pub const single = @import("single.zig");
pub const range = @import("range.zig");

pub const free_page = single.free_page;
pub const free_range = range.free_range;
