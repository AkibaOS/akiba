//! Interrupt vectors

pub const EXCEPTION_DIVIDE_ERROR: u8 = 0;
pub const EXCEPTION_DEBUG: u8 = 1;
pub const EXCEPTION_NMI: u8 = 2;
pub const EXCEPTION_BREAKPOINT: u8 = 3;
pub const EXCEPTION_OVERFLOW: u8 = 4;
pub const EXCEPTION_BOUND_RANGE: u8 = 5;
pub const EXCEPTION_INVALID_OPCODE: u8 = 6;
pub const EXCEPTION_DEVICE_NOT_AVAILABLE: u8 = 7;
pub const EXCEPTION_DOUBLE_FAULT: u8 = 8;
pub const EXCEPTION_INVALID_TSS: u8 = 10;
pub const EXCEPTION_SEGMENT_NOT_PRESENT: u8 = 11;
pub const EXCEPTION_STACK_FAULT: u8 = 12;
pub const EXCEPTION_GENERAL_PROTECTION: u8 = 13;
pub const EXCEPTION_PAGE_FAULT: u8 = 14;
pub const EXCEPTION_FPU_ERROR: u8 = 16;
pub const EXCEPTION_ALIGNMENT_CHECK: u8 = 17;
pub const EXCEPTION_MACHINE_CHECK: u8 = 18;
pub const EXCEPTION_SIMD_EXCEPTION: u8 = 19;

pub const IRQ_TIMER: u8 = 32;
pub const IRQ_KEYBOARD: u8 = 33;
pub const IRQ_CASCADE: u8 = 34;
pub const IRQ_COM2: u8 = 35;
pub const IRQ_COM1: u8 = 36;
pub const IRQ_LPT2: u8 = 37;
pub const IRQ_FLOPPY: u8 = 38;
pub const IRQ_LPT1: u8 = 39;
pub const IRQ_RTC: u8 = 40;
pub const IRQ_ACPI: u8 = 41;
pub const IRQ_AVAILABLE_10: u8 = 42;
pub const IRQ_AVAILABLE_11: u8 = 43;
pub const IRQ_MOUSE: u8 = 44;
pub const IRQ_FPU: u8 = 45;
pub const IRQ_PRIMARY_ATA: u8 = 46;
pub const IRQ_SECONDARY_ATA: u8 = 47;

pub const INTERRUPT_INVOCATION: u8 = 0x80;
