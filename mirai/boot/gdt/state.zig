//! GDT State

const entries = @import("entries.zig");
const types = @import("../types/types.zig");

const Entry = types.gdt.entry.Entry;
const GDTR = types.gdt.gdtr.GDTR;
const Table = types.gdt.table.Table;

var global_gdt: Table = undefined;
var initialized: bool = false;

pub fn getTable() *Table {
    return &global_gdt;
}

pub fn getGDTR() GDTR {
    return global_gdt.getGDTR();
}

pub fn isInitialized() bool {
    return initialized;
}

pub fn setInitialized() void {
    initialized = true;
}

pub fn setupEntries(tss_address: u64, tss_size: u20) void {
    global_gdt.Null = Entry.nullEntry();
    global_gdt.KernelCode = entries.createKernelCode();
    global_gdt.KernelData = entries.createKernelData();
    global_gdt.UserCode = entries.createUserCode();
    global_gdt.UserData = entries.createUserData();
    global_gdt.TSS = entries.createTSSDescriptor(tss_address, tss_size);
}

pub fn updateTSS(tss_address: u64, tss_size: u20) void {
    global_gdt.TSS = entries.createTSSDescriptor(tss_address, tss_size);
}
