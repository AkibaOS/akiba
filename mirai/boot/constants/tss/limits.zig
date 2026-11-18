//! TSS Limits

pub const TSS_SIZE: u20 = 104;

pub const IST_DOUBLE_FAULT: u8 = 1;
pub const IST_NMI: u8 = 2;
pub const IST_MACHINE_CHECK: u8 = 3;
pub const IST_DEBUG: u8 = 4;

pub const STACK_ALIGNMENT: u64 = 16;
