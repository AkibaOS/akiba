//! Interrupts

pub const constants = @import("constants/constants.zig");
pub const idt = @import("idt.zig");

pub const types = idt.types;
pub const table = idt.table;
pub const handlers = idt.handlers;
pub const load = idt.load;
pub const pic = idt.pic;

pub const Gate64 = idt.Gate64;
pub const Descriptor = idt.Descriptor;
pub const InterruptFrame = idt.InterruptFrame;

pub const initialize = idt.initialize;
pub const enable = idt.enable;
pub const disable = idt.disable;

pub const set_gate = idt.set_gate;
pub const set_interrupt = idt.set_interrupt;
pub const set_trap = idt.set_trap;
pub const register_irq = idt.register_irq;
pub const unregister_irq = idt.unregister_irq;
