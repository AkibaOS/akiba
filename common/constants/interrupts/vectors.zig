//! Interrupt Vector Constants

pub const DEBUG_VECTOR: u8 = 1;
pub const NMI_VECTOR: u8 = 2;
pub const DOUBLE_FAULT_VECTOR: u8 = 8;
pub const MACHINE_CHECK_VECTOR: u8 = 18;

pub const VECTOR_OFFSET: u8 = 32;
pub const EXCEPTION_COUNT: u8 = 32;
pub const IRQ_COUNT: u8 = 16;
