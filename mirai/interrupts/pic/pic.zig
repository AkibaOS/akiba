//! PIC - 8259A Programmable Interrupt Controller

pub const ports = @import("../constants/pic/ports.zig");
pub const init = @import("init.zig");
pub const mask = @import("mask.zig");
pub const eoi = @import("eoi.zig");

pub const remap = init.remap;
pub const disable = init.disable;
pub const enable_irq = mask.enable_irq;
pub const disable_irq = mask.disable_irq;
pub const mask_all = mask.mask_all;
pub const send_eoi = eoi.send;
