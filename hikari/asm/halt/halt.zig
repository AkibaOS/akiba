//! Hikari CPU Halt Operations

pub fn haltLoop() noreturn {
    while (true) {
        asm volatile ("hlt");
    }
}
