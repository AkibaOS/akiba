//! Kernel Heap Regression Inputs

const sizes = @import("common").constants.memory.sizes;

pub const LARGE_BYTES: usize = sizes.PAGE_SIZE + 1;
pub const SECOND_BYTES: usize = 3 * sizes.PAGE_SIZE + 17;
pub const FRAGMENT_FRAMES: usize = 64;
pub const ALIGNMENT: usize = 16 * sizes.PAGE_SIZE;
pub const TINY_BYTES: usize = 1;
