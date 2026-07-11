//! PIT - Programmable Interval Timer

pub const constants = @import("constants/constants.zig");
pub const init = @import("init.zig");
pub const handler = @import("handler.zig");

pub const initialize = init.init_default;
pub const register = handler.register;
pub const set_callback = handler.set_callback;
pub const get_ticks = handler.get_ticks;
