//! GDT Register Type

const asm_gdt = @import("../../../asm/gdt/gdt.zig");

pub const Gdtr = asm_gdt.Gdtr;

pub fn create(base_address: u64, num_entries: u16) Gdtr {
    return Gdtr{
        .limit = (num_entries * 8) - 1,
        .base = base_address,
    };
}

pub fn get_entry_count(gdtr: Gdtr) u16 {
    return (gdtr.limit + 1) / 8;
}
