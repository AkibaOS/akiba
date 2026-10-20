//! Hikari Kernel Image Limits

const sizes = @import("common").constants.memory.sizes;

pub const MAX_UNIT_SIZE: u64 = 64 * sizes.MEGABYTE;
pub const MAX_MEMORY_SIZE: u64 = 256 * sizes.MEGABYTE;
pub const SEGMENT_COUNT: usize = 7;
pub const STORED_SEGMENT_COUNT: usize = 3;
pub const TEXT_INDEX: usize = 0;
pub const READ_ONLY_INDEX: usize = 1;
pub const DATA_INDEX: usize = 2;
