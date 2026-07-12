//! Kernel Stack Limits

const common = @import("root").common;

const layout = common.constants.memory.layout;
const sizes = common.constants.memory.sizes;

pub const stack_size: u64 = layout.kernel_stack_size;
pub const stack_pages: u64 = layout.kernel_stack_pages;

pub const guard_pages: u64 = 1;

pub const slot_pages: u64 = stack_pages + 2 * guard_pages;
pub const slot_size: u64 = slot_pages * sizes.page_size;

pub const area_base: u64 = layout.kernel_stack_area_base;
pub const area_size: u64 = layout.kernel_stack_area_size;
pub const max_slots: u64 = area_size / slot_size;

pub const cache_target: u64 = 8;
