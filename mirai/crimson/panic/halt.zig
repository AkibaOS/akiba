//! Halt All CPUs

const cpu = @import("asm").cpu;
const interrupt = @import("asm").interrupts;

pub fn haltAll() noreturn {
    interrupt.flags.disableInterrupts();
    cpu.halt.haltLoop();
}

pub fn haltCurrent() noreturn {
    interrupt.flags.disableInterrupts();
    cpu.halt.haltLoop();
}

pub fn sendHaltIPI() void {}

pub fn waitForOtherCPUs() void {}
