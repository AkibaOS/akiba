//! Virtual Extent Regression Inputs

const layout = @import("common").constants.memory.layout;
const sizes = @import("common").constants.memory.sizes;

pub const BASE: u64 = layout.KERNEL_HEAP + sizes.PAGE_SIZE;
pub const BYTES: u64 = 1024 * sizes.PAGE_SIZE;
pub const RECORDS: usize = 273;
