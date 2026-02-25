//! Serial Driver

pub const init = @import("init.zig");
pub const write = @import("write.zig");

pub const initialize = init.initialize;
pub const initialize_default = init.initialize_default;

pub const set_port = write.set_port;
pub const printf = write.printf;
