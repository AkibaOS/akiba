//! FPU/SSE Operations

const strings = @import("asm").cpu.strings.fpu;

pub fn saveFpuState(address: u64) void {
    asm volatile (strings.SAVE_FPU_STATE
        :
        : [address] "r" (address),
        : .{ .memory = true });
}

pub fn restoreFpuState(address: u64) void {
    asm volatile (strings.RESTORE_FPU_STATE
        :
        : [address] "r" (address),
        : .{ .memory = true });
}

pub fn initializeFpu() void {
    asm volatile (strings.INITIALIZE_FPU);
}

pub fn clearFpuExceptions() void {
    asm volatile (strings.CLEAR_FPU_EXCEPTIONS);
}

pub fn storeMXCSR(address: *u32) void {
    asm volatile (strings.STORE_MXCSR
        :
        : [address] "r" (address),
        : .{ .memory = true });
}

pub fn loadMXCSR(address: *const u32) void {
    asm volatile (strings.LOAD_MXCSR
        :
        : [address] "r" (address),
        : .{ .memory = true });
}
