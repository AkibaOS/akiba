//! GDT Load Operations

const asm_gdt = @import("asm").gdt;
const constants = @import("../constants/constants.zig");

const selectors = constants.selectors;

pub const Gdtr = asm_gdt.Gdtr;
pub const lgdt = asm_gdt.lgdt;
pub const sgdt = asm_gdt.sgdt;

pub fn reload_segments() void {
    asm_gdt.reload_code_segment(selectors.kernel_code_selector);
    asm_gdt.reload_data_segments(selectors.kernel_data_selector);
}

pub const reload_code_segment = asm_gdt.reload_code_segment;
pub const reload_data_segments = asm_gdt.reload_data_segments;
pub const load_tss = asm_gdt.load_tss;

pub const get_cs = asm_gdt.get_cs;
pub const get_ds = asm_gdt.get_ds;
pub const get_ss = asm_gdt.get_ss;
