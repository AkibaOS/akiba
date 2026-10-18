//! Boot Memory Map Constants

const sizes = @import("common").constants.memory.sizes;

pub const DESCRIPTOR_VERSION: u32 = 1;
pub const MAX_REGIONS: usize = 512;
pub const MAX_DESCRIPTOR_SIZE: usize = sizes.PAGE_SIZE;
pub const MAX_MAP_BYTES: usize = MAX_REGIONS * MAX_DESCRIPTOR_SIZE;
