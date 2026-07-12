//! CPU State Operations

pub fn readStackPointer() u64 {
    var value: u64 = undefined;
    asm volatile ("mov %%rsp, %[value]"
        : [value] "=r" (value),
    );
    return value;
}

pub fn readBasePointer() u64 {
    var value: u64 = undefined;
    asm volatile ("mov %%rbp, %[value]"
        : [value] "=r" (value),
    );
    return value;
}

pub fn readFlags() u64 {
    var value: u64 = undefined;
    asm volatile ("pushfq; pop %[value]"
        : [value] "=r" (value),
    );
    return value;
}

pub fn readTimeStampCounter() u64 {
    var low: u32 = undefined;
    var high: u32 = undefined;
    asm volatile ("rdtsc"
        : [low] "={eax}" (low),
          [high] "={edx}" (high),
    );
    return (@as(u64, high) << 32) | low;
}

pub fn clearTaskSwitched() void {
    asm volatile (
        \\mov %%cr0, %%rax
        \\and $~8, %%rax
        \\mov %%rax, %%cr0
        ::: .{ .rax = true });
}
