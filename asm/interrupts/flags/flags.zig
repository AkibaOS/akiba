//! Interrupt Flag Operations

const strings = @import("asm").interrupts.strings.flags.instructions;

pub fn enableInterrupts() void {
    asm volatile (strings.ENABLE_INTERRUPTS ::: .{ .memory = true });
}

pub fn disableInterrupts() void {
    asm volatile (strings.DISABLE_INTERRUPTS ::: .{ .memory = true });
}
