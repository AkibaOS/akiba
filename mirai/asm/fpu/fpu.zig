//! FPU/SSE Operations

pub fn fxsave(addr: u64) void {
    asm volatile ("fxsave (%[addr])"
        :
        : [addr] "r" (addr),
        : .{ .memory = true }
    );
}

pub fn fxrstor(addr: u64) void {
    asm volatile ("fxrstor (%[addr])"
        :
        : [addr] "r" (addr),
        : .{ .memory = true }
    );
}

pub fn fninit() void {
    asm volatile ("fninit");
}

pub fn fnclex() void {
    asm volatile ("fnclex");
}

pub fn stmxcsr(addr: *u32) void {
    asm volatile ("stmxcsr (%[addr])"
        :
        : [addr] "r" (addr),
        : .{ .memory = true }
    );
}

pub fn ldmxcsr(addr: *const u32) void {
    asm volatile ("ldmxcsr (%[addr])"
        :
        : [addr] "r" (addr),
        : .{ .memory = true }
    );
}
