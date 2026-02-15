//! Task State Segment

const boot_limits = @import("../../common/limits/boot.zig");
const serial = @import("../../drivers/serial/serial.zig");

const TSS = packed struct {
    reserved1: u32,
    rsp0: u64,
    rsp1: u64,
    rsp2: u64,
    reserved2: u64,
    ist1: u64,
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
var kernel_stack: [boot_limits.KERNEL_STACK_SIZE]u8 align(16) = undefined;

pub fn init() void {
    const tss_bytes = @as([*]u8, @ptrCast(&tss));
    for (0..@sizeOf(TSS)) |i| {
        tss_bytes[i] = 0;
    }

    tss.rsp0 = @intFromPtr(&kernel_stack) + kernel_stack.len;

    serial.printf("TSS: addr={x} rsp0={x}\n", .{ @intFromPtr(&tss), tss.rsp0 });
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
