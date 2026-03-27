//! IDT Table

pub const entries = @import("entries.zig");
pub const install = @import("install.zig");

pub const set_gate = install.set_gate;
pub const set_interrupt = install.set_interrupt;
pub const set_trap = install.set_trap;
pub const set_interrupt_ist = install.set_interrupt_ist;
pub const clear_gate = install.clear_gate;
