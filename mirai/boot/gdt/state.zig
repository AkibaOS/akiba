//! GDT State

const types = @import("../types/gdt/gdt.zig");
const entries = @import("entries/entries.zig");

const Table = types.Table;
const Entry = types.Entry;
const TssDescriptor = types.TssDescriptor;
const Gdtr = types.Gdtr;

var global_gdt: Table = undefined;
var initialized: bool = false;

pub fn get_table() *Table {
    return &global_gdt;
}

pub fn get_gdtr() Gdtr {
    return global_gdt.get_gdtr();
}

pub fn is_initialized() bool {
    return initialized;
}

pub fn set_initialized() void {
    initialized = true;
}

pub fn setup_entries(tss_address: u64, tss_size: u20) void {
    global_gdt.null = Entry.null_entry();
    global_gdt.kernel_code = entries.create_kernel_code();
    global_gdt.kernel_data = entries.create_kernel_data();
    global_gdt.user_code = entries.create_user_code();
    global_gdt.user_data = entries.create_user_data();
    global_gdt.tss = entries.create_tss_descriptor(tss_address, tss_size);
}

pub fn update_tss(tss_address: u64, tss_size: u20) void {
    global_gdt.tss = entries.create_tss_descriptor(tss_address, tss_size);
}
