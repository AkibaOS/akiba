//! Model Specific Register Constants

pub const EFER: u32 = 0xC0000080;

pub const EFER_SYSCALL_ENABLE: u64 = 1 << 0;
pub const EFER_LONG_MODE_ENABLE: u64 = 1 << 8;
pub const EFER_LONG_MODE_ACTIVE: u64 = 1 << 10;
pub const EFER_NO_EXECUTE_ENABLE: u64 = 1 << 11;
