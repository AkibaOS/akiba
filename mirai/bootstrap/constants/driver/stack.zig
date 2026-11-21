//! Initial AHCI Driver Stack Geometry

const memory = @import("common").constants.memory;

pub const PAGES: u64 = 8;
pub const BASE: u64 = memory.layout.USER_SPACE_END + 1 - (PAGES + 1) * memory.sizes.PAGE_SIZE;
