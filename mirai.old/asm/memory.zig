//! Memory Management Operations
//! Wrappers for paging and memory control

/// Read page table base register
pub inline fn read_page_table_base() u64 {
    return asm volatile ("mov %%cr3, %[result]"
        : [result] "=r" (-> u64),
    );
}

/// Write page table base register
pub inline fn write_page_table_base(value: u64) void {
    asm volatile ("mov %[value], %%cr3"
        :
        : [value] "r" (value),
        : .{ .memory = true });
}

/// Read page fault address register
pub inline fn read_page_fault_address() u64 {
    return asm volatile ("mov %%cr2, %[result]"
        : [result] "=r" (-> u64),
    );
}

/// Invalidate translation lookaside buffer entry for given address
pub inline fn invalidate_page(address: u64) void {
    asm volatile ("invlpg (%[addr])"
        :
        : [addr] "r" (address),
        : .{ .memory = true });
}
