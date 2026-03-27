//! IDT Handlers

pub const common = @import("common.zig");
pub const exceptions = @import("exceptions.zig");
pub const hardware = @import("hardware.zig");

pub const InterruptFrame = common.InterruptFrame;
pub const register_irq = hardware.register_handler;
pub const unregister_irq = hardware.unregister_handler;
