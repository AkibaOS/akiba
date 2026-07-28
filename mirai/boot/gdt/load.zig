//! GDT Load Operations

const gdt = @import("asm").gdt;

const constants = @import("mirai").boot.constants;

const selectors = constants.gdt.selectors;

pub fn loadTable(descriptor: *const gdt.types.register.GDTR) void {
    gdt.table.loadGlobalDescriptorTable(descriptor);
}

pub fn reloadSegments() void {
    gdt.segment.reloadCodeSegment(selectors.KERNEL_CODE_SELECTOR);
    gdt.segment.reloadDataSegments(selectors.KERNEL_DATA_SELECTOR);
}

pub fn loadTaskStateSegment(selector: u16) void {
    gdt.segment.loadTaskStateSegment(selector);
}
