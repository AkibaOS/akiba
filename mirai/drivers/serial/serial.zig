//! Serial Driver

pub const init = @import("init.zig");
pub const write = @import("write.zig");

pub const initialize = init.initialize;
pub const initialize_default = init.initialize_default;

pub const set_port = write.set_port;
pub const print = write.print;
pub const print_character = write.print_character;
pub const print_hex = write.print_hex;
pub const print_decimal = write.print_decimal;
