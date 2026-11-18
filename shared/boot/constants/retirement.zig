//! Loader Table Ledger Geometry

const sizes = @import("common").constants.memory.sizes;

pub const LEDGER_CAPACITY: usize = (sizes.PAGE_SIZE - 4 * @sizeOf(u64)) / @sizeOf(u64);
