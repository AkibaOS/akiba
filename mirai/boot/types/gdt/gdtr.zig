//! GDT Register Type

const gdt = @import("asm").gdt;

pub const GDTR = gdt.types.register.GDTR;
