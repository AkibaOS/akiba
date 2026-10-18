//! Hikari Paging Limits

const sizes = @import("common").constants.memory.sizes;

pub const MAX_ALLOCATED_TABLES: usize = 2 * sizes.ENTRIES_PER_PAGE_TABLE;
