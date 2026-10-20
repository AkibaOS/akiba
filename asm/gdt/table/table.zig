//! GDT Table Load Operations

const register = @import("asm").gdt.types.register;
const strings = @import("asm").gdt.strings.table;

pub fn loadGlobalDescriptorTable(descriptor: *const register.GDTR) void {
    asm volatile (strings.LOAD_GLOBAL_DESCRIPTOR_TABLE
        :
        : [descriptor] "r" (descriptor),
        : .{ .memory = true });
}

pub fn storeGlobalDescriptorTable() register.GDTR {
    var descriptor: register.GDTR = undefined;
    asm volatile (strings.STORE_GLOBAL_DESCRIPTOR_TABLE
        :
        : [descriptor] "r" (&descriptor),
        : .{ .memory = true });
    return descriptor;
}
