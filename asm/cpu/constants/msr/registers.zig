//! Model Specific Register Constants

pub const EFER: u32 = 0xC0000080;
pub const PAT: u32 = 0x277;

pub const PAT_ENTRY_MASK: u64 = 0xFF;
pub const PAT_WRITE_BACK: u64 = 0x06;
pub const PAT_UNCACHEABLE: u64 = 0x00;
pub const PAT_FRAMEBUFFER_SHIFT: u6 = 24;

pub const EFER_SYSCALL_ENABLE: u64 = 1 << 0;
pub const EFER_LONG_MODE_ENABLE: u64 = 1 << 8;
pub const EFER_LONG_MODE_ACTIVE: u64 = 1 << 10;
pub const EFER_NO_EXECUTE_ENABLE: u64 = 1 << 11;
