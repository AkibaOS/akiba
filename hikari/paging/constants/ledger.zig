//! Loader Table Metadata Page Geometry

const sizes = @import("common").constants.memory.sizes;

pub const CAPACITY: usize = (sizes.PAGE_SIZE - @sizeOf(?*anyopaque) - @sizeOf(usize)) / @sizeOf(u64);
