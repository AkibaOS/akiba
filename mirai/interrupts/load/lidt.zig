//! IDT Load Operations

const interrupt = @import("asm").interrupts;

const table = @import("mirai").interrupts.table;
const types = @import("mirai").interrupts.types;

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
