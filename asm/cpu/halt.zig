//! CPU Halt Operations

pub fn halt() void {
    asm volatile ("hlt");
}

pub fn halt_loop() noreturn {
    while (true) {
        halt();
    }
}

pub fn enable_interrupts() void {
    asm volatile ("sti");
}

pub fn disable_interrupts() void {
    asm volatile ("cli");
}

pub fn are_interrupts_enabled() bool {
    const flags = read_flags();
    return (flags & 0x200) != 0;
}

pub fn read_flags() u64 {
    var result: u64 = undefined;
    asm volatile ("pushfq; pop %[result]"
        : [result] "=r" (result),
    );
    return result;
}

pub fn pause() void {
    asm volatile ("pause");
}
