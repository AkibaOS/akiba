//! IDT Load Operations

pub fn loadInterruptDescriptorTable(descriptor: *const anyopaque) void {
    asm volatile ("lidt (%[descriptor])"
        :
        : [descriptor] "r" (descriptor),
        : .{ .memory = true });
}

pub fn storeInterruptDescriptorTable(descriptor: *anyopaque) void {
    asm volatile ("sidt (%[descriptor])"
        :
        : [descriptor] "r" (descriptor),
        : .{ .memory = true });
}
