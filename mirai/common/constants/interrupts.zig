//! Interrupt Constants - Exception and IRQ vectors

// ============================================================================
// Exception Vectors
// ============================================================================

/// Divide by zero exception
pub const EXCEPTION_DIVIDE_ERROR: u8 = 0;

/// Debug exception
pub const EXCEPTION_DEBUG: u8 = 1;

/// Non-maskable interrupt
pub const EXCEPTION_NMI: u8 = 2;

/// Breakpoint exception
pub const EXCEPTION_BREAKPOINT: u8 = 3;

/// Overflow exception
pub const EXCEPTION_OVERFLOW: u8 = 4;

/// Bound range exceeded
pub const EXCEPTION_BOUND_RANGE: u8 = 5;

/// Invalid opcode
pub const EXCEPTION_INVALID_OPCODE: u8 = 6;

/// Device not available
pub const EXCEPTION_DEVICE_NOT_AVAILABLE: u8 = 7;

/// Double fault
pub const EXCEPTION_DOUBLE_FAULT: u8 = 8;

/// Invalid TSS
pub const EXCEPTION_INVALID_TSS: u8 = 10;

/// Segment not present
pub const EXCEPTION_SEGMENT_NOT_PRESENT: u8 = 11;

/// Stack-segment fault
pub const EXCEPTION_STACK_FAULT: u8 = 12;

/// General protection fault
pub const EXCEPTION_GENERAL_PROTECTION: u8 = 13;

/// Page fault
pub const EXCEPTION_PAGE_FAULT: u8 = 14;

/// x87 FPU error
pub const EXCEPTION_FPU_ERROR: u8 = 16;

/// Alignment check
pub const EXCEPTION_ALIGNMENT_CHECK: u8 = 17;

/// Machine check
pub const EXCEPTION_MACHINE_CHECK: u8 = 18;

/// SIMD floating-point exception
pub const EXCEPTION_SIMD_EXCEPTION: u8 = 19;

// ============================================================================
// Hardware IRQ Vectors
// ============================================================================

/// Timer interrupt vector (IRQ 0)
pub const IRQ_TIMER: u8 = 32;

/// Keyboard interrupt vector (IRQ 1)
pub const IRQ_KEYBOARD: u8 = 33;

/// Cascade (IRQ 2) - used internally by PICs
pub const IRQ_CASCADE: u8 = 34;

/// COM2/COM4 serial port (IRQ 3)
pub const IRQ_COM2: u8 = 35;

/// COM1/COM3 serial port (IRQ 4)
pub const IRQ_COM1: u8 = 36;

/// LPT2 parallel port (IRQ 5)
pub const IRQ_LPT2: u8 = 37;

/// Floppy disk controller (IRQ 6)
pub const IRQ_FLOPPY: u8 = 38;

/// LPT1 parallel port (IRQ 7)
pub const IRQ_LPT1: u8 = 39;

/// Real-time clock (IRQ 8)
pub const IRQ_RTC: u8 = 40;

/// ACPI (IRQ 9)
pub const IRQ_ACPI: u8 = 41;

/// Available (IRQ 10)
pub const IRQ_AVAILABLE_10: u8 = 42;

/// Available (IRQ 11)
pub const IRQ_AVAILABLE_11: u8 = 43;

/// PS/2 Mouse (IRQ 12)
pub const IRQ_MOUSE: u8 = 44;

/// FPU/Coprocessor (IRQ 13)
pub const IRQ_FPU: u8 = 45;

/// Primary ATA (IRQ 14)
pub const IRQ_PRIMARY_ATA: u8 = 46;

/// Secondary ATA (IRQ 15)
pub const IRQ_SECONDARY_ATA: u8 = 47;

// ============================================================================
// Software Interrupt Vectors
// ============================================================================

/// Invocation interrupt vector
pub const INTERRUPT_INVOCATION: u8 = 0x80;
