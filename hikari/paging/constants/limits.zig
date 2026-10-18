//! Hikari Paging Limits

const sizes = @import("common").constants.memory.sizes;

pub const MAX_ALLOCATED_TABLES: usize = 4 * sizes.ENTRIES_PER_PAGE_TABLE;
pub const PML4_ENTRY_SIZE: u64 = sizes.HUGE_PAGE_SIZE * sizes.ENTRIES_PER_PAGE_TABLE;
pub const CANONICAL_LOW_MAX: u64 = 0x00007FFFFFFFFFFF;
pub const CANONICAL_HIGH_MIN: u64 = 0xFFFF800000000000;
