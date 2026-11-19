//! Stable Storage Regression Inputs

const sizes = @import("common").constants.memory.sizes;

pub const LIVE_COUNT: usize = 273;
pub const VALUE_BYTES: usize = 32;
pub const VALUE_ALIGNMENT: usize = 16;
pub const INTERIOR_OFFSET: usize = 16;
pub const PAGE_VALUE_BYTES: usize = sizes.PAGE_SIZE / 2;
pub const OVERSIZED_BYTES: usize = sizes.PAGE_SIZE;
pub const OVER_ALIGNMENT: usize = sizes.PAGE_SIZE * 2;
