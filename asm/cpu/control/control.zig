//! CPU Control Register Operations

pub fn readCR0() u64 {
    var result: u64 = undefined;
    asm volatile ("mov %%cr0, %[result]"
        : [result] "=r" (result),
    );
    return result;
}

pub fn writeCR0(value: u64) void {
    asm volatile ("mov %[value], %%cr0"
        :
        : [value] "r" (value),
    );
}

pub fn readCR2() u64 {
    var result: u64 = undefined;
    asm volatile ("mov %%cr2, %[result]"
        : [result] "=r" (result),
    );
    return result;
}

pub fn readCR3() u64 {
    var result: u64 = undefined;
    asm volatile ("mov %%cr3, %[result]"
        : [result] "=r" (result),
    );
    return result;
}

pub fn writeCR3(value: u64) void {
    asm volatile ("mov %[value], %%cr3"
        :
        : [value] "r" (value),
        : .{ .memory = true });
}

pub fn readCR4() u64 {
    var result: u64 = undefined;
    asm volatile ("mov %%cr4, %[result]"
        : [result] "=r" (result),
    );
    return result;
}

pub fn writeCR4(value: u64) void {
    asm volatile ("mov %[value], %%cr4"
        :
        : [value] "r" (value),
    );
}

pub fn flushTLB() void {
    const current = readCR3();
    writeCR3(current);
}

pub fn invalidatePage(virtual_address: u64) void {
    asm volatile ("invlpg (%[address])"
        :
        : [address] "r" (virtual_address),
        : .{ .memory = true });
}
