//! CPU Halt Operations

const strings = @import("asm").cpu.strings.halt;

pub fn waitForInterrupt() void {
    asm volatile (strings.WAIT_FOR_INTERRUPT ::: .{ .memory = true });
}

pub fn halt() void {
    asm volatile (strings.HALT);
}

pub fn haltLoop() noreturn {
    while (true) {
        halt();
    }
}

pub fn pause() void {
    asm volatile (strings.PAUSE);
}
