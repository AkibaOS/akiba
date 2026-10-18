//! Early Processor Contract Constants

const control = @import("asm").cpu.constants.control;

pub const CR0_REQUIRED: u64 = control.CR0_MONITOR_COPROCESSOR | control.CR0_NUMERIC_ERROR | control.CR0_WRITE_PROTECT;
pub const CR0_FORBIDDEN: u64 = control.CR0_EMULATION | control.CR0_TASK_SWITCHED;
pub const CR4_REQUIRED: u64 = control.CR4_OS_FXSAVE | control.CR4_OS_XMM_EXCEPTION;
pub const CR4_FORBIDDEN: u64 = control.CR4_OS_XSAVE;
