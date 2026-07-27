//! Kernel Stack Limits

const common = @import("common");

const layout = common.constants.memory.layout;
const sizes = common.constants.memory.sizes;

pub const STACK_SIZE: u64 = layout.KERNEL_STACK_SIZE;
pub const STACK_PAGES: u64 = layout.KERNEL_STACK_PAGES;

pub const GUARD_PAGES: u64 = 1;

pub const SLOT_PAGES: u64 = STACK_PAGES + 2 * GUARD_PAGES;
pub const SLOT_SIZE: u64 = SLOT_PAGES * sizes.PAGE_SIZE;

pub const AREA_BASE: u64 = layout.KERNEL_STACK_AREA_BASE;
pub const AREA_SIZE: u64 = layout.KERNEL_STACK_AREA_SIZE;
pub const MAX_SLOTS: u64 = AREA_SIZE / SLOT_SIZE;

pub const CACHE_TARGET: u64 = 8;
