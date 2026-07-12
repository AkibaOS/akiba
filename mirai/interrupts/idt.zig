//! IDT - Interrupt Descriptor Table

const gdt = @import("../boot/gdt/gdt.zig");
const asm_int = @import("asm").interrupts;

pub const types = @import("types/types.zig");
pub const table = @import("table/table.zig");
pub const handlers = @import("handlers/handlers.zig");
pub const load = @import("load/load.zig");
pub const pic = @import("pic/pic.zig");

pub const Gate64 = types.Gate64;
pub const Descriptor = types.Descriptor;
pub const InterruptFrame = handlers.InterruptFrame;

pub const set_gate = table.set_gate;
pub const set_interrupt = table.set_interrupt;
pub const set_trap = table.set_trap;
pub const register_irq = handlers.register_irq;
pub const unregister_irq = handlers.unregister_irq;

pub fn initialize() void {
    pic.remap();
    pic.mask_all();

    const selector = gdt.selectors.kernel_code_selector;

    for (0..32) |i| {
        const vector: u8 = @truncate(i);
        const handler_ptr = @intFromPtr(handlers.exceptions.stubs[i]);
        table.set_interrupt(vector, handler_ptr, selector);
    }

    for (0..16) |i| {
        const vector: u8 = @truncate(i + 32);
        const handler_ptr = @intFromPtr(handlers.hardware.stubs[i]);
        table.set_interrupt(vector, handler_ptr, selector);
    }

    load.load();
}

pub fn enable() void {
    asm_int.enable();
}

pub fn disable() void {
    asm_int.disable();
}
