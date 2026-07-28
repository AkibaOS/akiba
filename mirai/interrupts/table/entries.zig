//! IDT Entries Table

const constants = @import("mirai").interrupts.constants;
const types = @import("mirai").interrupts.types;

const IDT_ENTRIES = constants.idt.limits.IDT_ENTRIES;

pub var entries: [IDT_ENTRIES]types.gate.Gate64 = [_]types.gate.Gate64{types.gate.Gate64.empty()} ** IDT_ENTRIES;
