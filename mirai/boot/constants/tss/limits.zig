//! TSS Limits

pub const TSS_SIZE: u20 = 104;

pub const IST_COUNT: u8 = 7;

pub const IST_DOUBLE_FAULT: u8 = 1;
pub const IST_NMI: u8 = 2;
pub const IST_MACHINE_CHECK: u8 = 3;
pub const IST_DEBUG: u8 = 4;

pub const DEFAULT_STACK_SIZE: u64 = 16 * 1024;
pub const INTERRUPT_STACK_SIZE: u64 = 8 * 1024;

pub const MAX_CORES: u16 = 256;
