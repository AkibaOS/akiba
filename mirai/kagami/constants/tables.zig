//! Kagami Table Constants

const common = @import("common");

const sizes = common.constants.memory.sizes;

pub const PML4_ENTRIES: u64 = sizes.ENTRIES_PER_PAGE_TABLE;
pub const PDPT_ENTRIES: u64 = sizes.ENTRIES_PER_PAGE_TABLE;
pub const PD_ENTRIES: u64 = sizes.ENTRIES_PER_PAGE_TABLE;
pub const PT_ENTRIES: u64 = sizes.ENTRIES_PER_PAGE_TABLE;

pub const KERNEL_PML4_START: u64 = 256;
pub const KERNEL_PML4_END: u64 = 512;

pub const USER_PML4_START: u64 = 0;
pub const USER_PML4_END: u64 = 256;
