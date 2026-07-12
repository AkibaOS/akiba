//! Keyboard Driver

pub const constants = @import("../constants/keyboard/keyboard.zig");
pub const handler = @import("handler.zig");

pub const register = handler.register;
pub const get_last_scancode = handler.get_last_scancode;
