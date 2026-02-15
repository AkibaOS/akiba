//! Paging constants

pub const PTE_PRESENT: u64 = 1 << 0;
pub const PTE_WRITABLE: u64 = 1 << 1;
pub const PTE_USER: u64 = 1 << 2;

pub const PTE_MASK: u64 = 0x000FFFFFFFFFF000;
pub const OFFSET_MASK: u64 = 0xFFF;

pub const PML4_ENTRIES: usize = 512;
pub const KERNEL_PML4_START: usize = 256;
