//! Hikari Paging Constants

pub const page_size: u64 = 4096;
pub const page_shift: u6 = 12;

pub const entries_per_table: u64 = 512;
pub const entry_shift: u6 = 9;

pub const pml4_shift: u6 = 39;
pub const pdpt_shift: u6 = 30;
pub const pd_shift: u6 = 21;
pub const pt_shift: u6 = 12;

pub const huge_page_size_1g: u64 = 1 << 30;
pub const huge_page_size_2m: u64 = 1 << 21;

pub const flag_present: u64 = 1 << 0;
pub const flag_writable: u64 = 1 << 1;
pub const flag_user: u64 = 1 << 2;
pub const flag_write_through: u64 = 1 << 3;
pub const flag_cache_disable: u64 = 1 << 4;
pub const flag_accessed: u64 = 1 << 5;
pub const flag_dirty: u64 = 1 << 6;
pub const flag_huge_page: u64 = 1 << 7;
pub const flag_global: u64 = 1 << 8;
pub const flag_no_execute: u64 = 1 << 63;

pub const address_mask: u64 = 0x000FFFFFFFFFF000;

pub const kernel_base: u64 = 0xFFFFFFFF80000000;
pub const physmap_base: u64 = 0xFFFF800000000000;
pub const physmap_size: u64 = 512 * huge_page_size_1g;

pub const pml4_index_kernel: u64 = 511;
pub const pml4_index_physmap: u64 = 256;
