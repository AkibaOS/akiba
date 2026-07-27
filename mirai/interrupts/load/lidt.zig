//! IDT Load Operations

const interrupt = @import("asm").interrupts;

const table = @import("../table/table.zig");
const types = @import("../types/types.zig");

const Descriptor = types.descriptor.Descriptor;

pub fn loadDescriptor(descriptor: *const Descriptor) void {
    interrupt.idt.loadInterruptDescriptorTable(descriptor);
}

pub fn load() void {
    const descriptor = Descriptor.fromTable(&table.entries.entries);
    loadDescriptor(&descriptor);
}

pub fn store() Descriptor {
    var descriptor: Descriptor = undefined;
    interrupt.idt.storeInterruptDescriptorTable(&descriptor);
    return descriptor;
}
