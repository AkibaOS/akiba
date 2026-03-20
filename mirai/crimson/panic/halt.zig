//! Halt All CPUs

const asm_cpu = @import("../../asm/cpu/cpu.zig");

pub fn halt_all() noreturn {
    asm_cpu.disable_interrupts();
    asm_cpu.halt_loop();
}

pub fn halt_current() noreturn {
    asm_cpu.disable_interrupts();
    asm_cpu.halt_loop();
}

pub fn send_halt_ipi() void {
    // TODO: Send IPI to all other cores to halt them
}

pub fn wait_for_other_cpus() void {
    // TODO: Wait for all other CPUs to acknowledge halt
}
