//! TSS Constants

pub const tss_size: u20 = 104;

pub const ist_count: u8 = 7;

pub const ist_double_fault: u8 = 1;
pub const ist_nmi: u8 = 2;
pub const ist_machine_check: u8 = 3;
pub const ist_debug: u8 = 4;

pub const default_stack_size: u64 = 16 * 1024;
pub const interrupt_stack_size: u64 = 8 * 1024;

pub const max_cores: u16 = 256;
