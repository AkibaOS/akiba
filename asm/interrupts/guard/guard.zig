//! Uniprocessor Interrupt Guard

const constants = @import("asm").cpu.constants.control;
const cpu = @import("asm").cpu.state;
const flags = @import("asm").interrupts.flags;

pub fn acquire() u64 {
    const previous_flags = cpu.readFlags();
    flags.disableInterrupts();
    return previous_flags;
}

pub fn release(previous_flags: u64) void {
    if ((previous_flags & constants.RFLAGS_INTERRUPT_ENABLE) != 0) flags.enableInterrupts();
}
