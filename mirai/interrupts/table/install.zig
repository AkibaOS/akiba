//! IDT Gate Installation

const entries = @import("mirai").interrupts.table.entries;
const types = @import("mirai").interrupts.types;

const DPL = types.gate.DPL;
const Gate64 = types.gate.Gate64;
const GateType = types.gate.GateType;

pub fn setGate(vector: u8, handler: u64, selector: u16, ist: u3, dpl: DPL, gate_type: GateType) void {
    entries.entries[vector] = switch (gate_type) {
        .Interrupt => Gate64.interrupt(handler, selector, ist, dpl),
        .Trap => Gate64.trap(handler, selector, ist, dpl),
    };
}

pub fn setInterrupt(vector: u8, handler: u64, selector: u16) void {
    setGate(vector, handler, selector, 0, .Ring0, .Interrupt);
}

pub fn setTrap(vector: u8, handler: u64, selector: u16) void {
    setGate(vector, handler, selector, 0, .Ring0, .Trap);
}

pub fn setInterruptIST(vector: u8, handler: u64, selector: u16, ist: u3) void {
    setGate(vector, handler, selector, ist, .Ring0, .Interrupt);
}

pub fn clearGate(vector: u8) void {
    entries.entries[vector] = Gate64.empty();
}
