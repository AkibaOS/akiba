//! Model Specific Register Operations
//! Wrappers for reading and writing CPU-specific registers

/// Read model specific register
pub inline fn read_msr(register: u32) u64 {
    var low: u32 = undefined;
    var high: u32 = undefined;
    asm volatile ("rdmsr"
        : [low] "={eax}" (low),
          [high] "={edx}" (high),
        : [msr] "{ecx}" (register),
    );
    return (@as(u64, high) << 32) | @as(u64, low);
}

/// Write model specific register
pub inline fn write_msr(register: u32, value: u64) void {
    const low: u32 = @truncate(value);
    const high: u32 = @truncate(value >> 32);
    asm volatile ("wrmsr"
        :
        : [msr] "{ecx}" (register),
          [low] "{eax}" (low),
          [high] "{edx}" (high),
    );
}
