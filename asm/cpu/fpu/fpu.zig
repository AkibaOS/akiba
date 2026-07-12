//! FPU/SSE Operations

pub fn saveFpuState(address: u64) void {
    asm volatile ("fxsave (%[address])"
        :
        : [address] "r" (address),
        : .{ .memory = true });
}

pub fn restoreFpuState(address: u64) void {
    asm volatile ("fxrstor (%[address])"
        :
        : [address] "r" (address),
        : .{ .memory = true });
}

pub fn initializeFpu() void {
    asm volatile ("fninit");
}

pub fn clearFpuExceptions() void {
    asm volatile ("fnclex");
}

pub fn storeMXCSR(address: *u32) void {
    asm volatile ("stmxcsr (%[address])"
        :
        : [address] "r" (address),
        : .{ .memory = true });
}

pub fn loadMXCSR(address: *const u32) void {
    asm volatile ("ldmxcsr (%[address])"
        :
        : [address] "r" (address),
        : .{ .memory = true });
}
