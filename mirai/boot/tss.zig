//! Task State Segment - For stack switching between layers

const serial = @import("../drivers/serial.zig");

// TSS structure for x64
const TSS = packed struct {
    reserved1: u32,
    rsp0: u64, // Kernel stack pointer (Layer 0)
    rsp1: u64, // Layer 1 stack (unused)
    rsp2: u64, // Layer 2 stack (unused)
    reserved2: u64,
    ist1: u64, // Interrupt Stack Table 1
    ist2: u64,
    ist3: u64,
    ist4: u64,
    ist5: u64,
    ist6: u64,
    ist7: u64,
    reserved3: u64,
    reserved4: u16,
    iomap_base: u16,
};

var tss: TSS align(16) = undefined;
var kernel_stack: [16384]u8 align(16) = undefined;

pub fn init() void {
    serial.print("\n=== Task State Segment ===\n");

    // Zero out TSS
    const tss_bytes = @as([*]u8, @ptrCast(&tss));
    var i: usize = 0;
    while (i < @sizeOf(TSS)) : (i += 1) {
        tss_bytes[i] = 0;
    }

    // Set kernel stack pointer (grows down, so point to top)
    tss.rsp0 = @intFromPtr(&kernel_stack) + kernel_stack.len;

    serial.print("TSS at: ");
    serial.print_hex(@intFromPtr(&tss));
    serial.print("\n");
    serial.print("Kernel stack (RSP0): ");
    serial.print_hex(tss.rsp0);
    serial.print("\n");
}

pub fn get_address() u64 {
    return @intFromPtr(&tss);
}

pub fn get_size() u64 {
    return @sizeOf(TSS) - 1;
}

pub fn set_kernel_stack(stack_pointer: u64) void {
    tss.rsp0 = stack_pointer;
}

pub fn get_kernel_stack() u64 {
    return tss.rsp0;
}
