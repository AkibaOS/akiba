//! CPU Control Register Operations

pub fn read_cr0() u64 {
    var result: u64 = undefined;
    asm volatile ("mov %%cr0, %[result]"
        : [result] "=r" (result),
    );
    return result;
}

pub fn write_cr0(value: u64) void {
    asm volatile ("mov %[value], %%cr0"
        :
        : [value] "r" (value),
    );
}

pub fn read_cr2() u64 {
    var result: u64 = undefined;
    asm volatile ("mov %%cr2, %[result]"
        : [result] "=r" (result),
    );
    return result;
}

pub fn read_cr3() u64 {
    var result: u64 = undefined;
    asm volatile ("mov %%cr3, %[result]"
        : [result] "=r" (result),
    );
    return result;
}

pub fn write_cr3(value: u64) void {
    asm volatile ("mov %[value], %%cr3"
        :
        : [value] "r" (value),
        : .{ .memory = true });
}

pub fn read_cr4() u64 {
    var result: u64 = undefined;
    asm volatile ("mov %%cr4, %[result]"
        : [result] "=r" (result),
    );
    return result;
}

pub fn write_cr4(value: u64) void {
    asm volatile ("mov %[value], %%cr4"
        :
        : [value] "r" (value),
    );
}

pub fn flush_tlb() void {
    const cr3_value = read_cr3();
    write_cr3(cr3_value);
}

pub fn invalidate_page(virtual_address: u64) void {
    asm volatile ("invlpg (%[address])"
        :
        : [address] "r" (virtual_address),
        : .{ .memory = true });
}
