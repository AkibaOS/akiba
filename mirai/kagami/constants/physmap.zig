//! Owned Physmap Split Bounds

const common = @import("common");

const indices = common.constants.paging.indices;

pub const MAX_SPLIT_TABLES: usize = 2;
pub const BIG_PAT: u64 = 1 << 12;
pub const PARENT_SHIFTS = [_]u6{ indices.PML4_SHIFT, indices.PDPT_SHIFT, indices.PD_SHIFT };
