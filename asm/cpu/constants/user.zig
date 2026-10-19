//! Ring Three Entry Constants

const control = @import("asm").cpu.constants.control;

pub const RFLAGS_INITIAL: u64 = control.RFLAGS_RESERVED | control.RFLAGS_INTERRUPT_ENABLE;
pub const SELECTOR_MAX: u64 = 0xFFFF;
pub const SELECTOR_RPL_MASK: u64 = 0x3;
pub const SELECTOR_RPL_USER: u64 = 0x3;
pub const STACK_ALIGNMENT: u64 = 16;
