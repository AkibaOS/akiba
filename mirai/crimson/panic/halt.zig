//! Halt The Current CPU

const cpu = @import("asm").cpu;
const interrupt = @import("asm").interrupts;

pub fn haltCurrent() noreturn {
    interrupt.flags.disableInterrupts();
    cpu.halt.haltLoop();
}
