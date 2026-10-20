//! Hikari CPU Halt Operations

const strings = @import("hikari").assembly.strings.halt;

pub fn haltLoop() noreturn {
    while (true) {
        asm volatile (strings.HALT);
    }
}
