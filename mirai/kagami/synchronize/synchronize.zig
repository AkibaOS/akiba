//! Uniprocessor Mapping Serialization

const cpu = @import("asm").cpu;
const flags = @import("asm").interrupts.flags;

pub fn acquire() u64 {
    const previous_flags = cpu.state.readFlags();
    flags.disableInterrupts();
    return previous_flags;
}

pub fn release(previous_flags: u64) void {
    if ((previous_flags & cpu.constants.control.RFLAGS_INTERRUPT_ENABLE) != 0) {
        flags.enableInterrupts();
    }
}
