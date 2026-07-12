//! CPU Halt Operations

pub fn halt() void {
    asm volatile ("hlt");
}

pub fn haltLoop() noreturn {
    while (true) {
        halt();
    }
}

pub fn pause() void {
    asm volatile ("pause");
}