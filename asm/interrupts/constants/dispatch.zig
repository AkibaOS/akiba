//! Interrupt Dispatch Stack Constants

const fpu = @import("asm").cpu.constants.fpu;

pub const KERNEL_MXCSR_OFFSET: usize = fpu.STATE_SIZE;
pub const STACK_SIZE: usize = fpu.STATE_SIZE + fpu.STATE_ALIGNMENT;
