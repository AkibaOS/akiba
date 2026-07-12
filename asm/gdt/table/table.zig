//! GDT Table Load Operations

const register = @import("../types/register.zig");

pub fn loadGlobalDescriptorTable(descriptor: *const register.GDTR) void {
    asm volatile ("lgdt (%[descriptor])"
        :
        : [descriptor] "r" (descriptor),
        : .{ .memory = true });
}

pub fn storeGlobalDescriptorTable() register.GDTR {
    var descriptor: register.GDTR = undefined;
    asm volatile ("sgdt (%[descriptor])"
        :
        : [descriptor] "r" (&descriptor),
        : .{ .memory = true });
    return descriptor;
}
