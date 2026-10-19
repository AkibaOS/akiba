//! Invocation ABI Constants

const control = @import("asm").cpu.constants.control;

pub const VERSION: u64 = 1;
pub const USER_FLAGS_MASK: u64 = (1 << 0) | (1 << 2) | (1 << 4) | (1 << 6) | (1 << 7) | control.RFLAGS_DIRECTION | (1 << 11);
pub const USER_FLAGS_REQUIRED: u64 = control.RFLAGS_RESERVED | control.RFLAGS_INTERRUPT_ENABLE;
pub const INVALID_RETURN_VECTOR: u64 = 13;
