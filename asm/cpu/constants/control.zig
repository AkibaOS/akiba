//! CPU Control Register Constants

pub const CR0_MONITOR_COPROCESSOR: u64 = 1 << 1;
pub const CR0_EMULATION: u64 = 1 << 2;
pub const CR0_TASK_SWITCHED: u64 = 1 << 3;
pub const CR0_NUMERIC_ERROR: u64 = 1 << 5;
pub const CR0_WRITE_PROTECT: u64 = 1 << 16;
pub const CR4_PAGE_GLOBAL_ENABLE: u64 = 1 << 7;
pub const CR4_OS_FXSAVE: u64 = 1 << 9;
pub const CR4_OS_XMM_EXCEPTION: u64 = 1 << 10;
pub const CR4_LINEAR_ADDRESS_57_ENABLE: u64 = 1 << 12;
pub const CR4_PCID_ENABLE: u64 = 1 << 17;
pub const CR4_OS_XSAVE: u64 = 1 << 18;
pub const RFLAGS_INTERRUPT_ENABLE: u64 = 1 << 9;
