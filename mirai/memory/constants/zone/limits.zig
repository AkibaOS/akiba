//! Zone Allocator Limits

const sizes = @import("common").constants.memory.sizes;

pub const NAME_CAPACITY: usize = 32;
pub const ELEMENT_ALIGNMENT: usize = 8;
pub const EARLY_META_COUNT: usize = 4;
pub const ALLOCATION_BITMAP_BYTES: usize = (sizes.PAGE_SIZE / ELEMENT_ALIGNMENT + @bitSizeOf(u8) - 1) / @bitSizeOf(u8);
