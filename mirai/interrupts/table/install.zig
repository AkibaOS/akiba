//! IDT Gate Installation

const types = @import("../types/types.zig");
const entries = @import("entries.zig");

pub fn set_gate(vector: u8, handler: u64, selector: u16, ist: u3, dpl: types.DPL, gate_type: types.GateType) void {
    entries.entries[vector] = switch (gate_type) {
        .interrupt => types.Gate64.interrupt(handler, selector, ist, dpl),
        .trap => types.Gate64.trap(handler, selector, ist, dpl),
    };
}

pub fn set_interrupt(vector: u8, handler: u64, selector: u16) void {
    set_gate(vector, handler, selector, 0, .ring0, .interrupt);
}

pub fn set_trap(vector: u8, handler: u64, selector: u16) void {
    set_gate(vector, handler, selector, 0, .ring0, .trap);
}

pub fn set_interrupt_ist(vector: u8, handler: u64, selector: u16, ist: u3) void {
    set_gate(vector, handler, selector, ist, .ring0, .interrupt);
}

pub fn clear_gate(vector: u8) void {
    entries.entries[vector] = types.Gate64.empty();
}
