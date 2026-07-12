//! Interrupt Assembly Operations

pub const idt = @import("idt.zig");
pub const flags = @import("flags.zig");
pub const stubs = @import("stubs.zig");

pub const lidt = idt.lidt;
pub const sidt = idt.sidt;
pub const enable = flags.enable;
pub const disable = flags.disable;
pub const are_enabled = flags.are_enabled;
