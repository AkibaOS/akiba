//! IDT Load Operations

const strings = @import("asm").interrupts.strings.idt;

pub fn loadInterruptDescriptorTable(descriptor: *const anyopaque) void {
    asm volatile (strings.LOAD_INTERRUPT_DESCRIPTOR_TABLE
        :
        : [descriptor] "r" (descriptor),
        : .{ .memory = true });
}

pub fn storeInterruptDescriptorTable(descriptor: *anyopaque) void {
    asm volatile (strings.STORE_INTERRUPT_DESCRIPTOR_TABLE
        :
        : [descriptor] "r" (descriptor),
        : .{ .memory = true });
}
