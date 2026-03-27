//! Interrupt Flag Operations

pub fn enable() void {
    asm volatile ("sti");
}

pub fn disable() void {
    asm volatile ("cli");
}

pub fn read_flags() u64 {
    var flags: u64 = undefined;
    asm volatile (
        \\pushfq
        \\pop %[flags]
        : [flags] "=r" (flags),
    );
    return flags;
}

pub fn are_enabled() bool {
    return (read_flags() & 0x200) != 0;
}
