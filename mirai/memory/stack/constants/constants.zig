//! Kernel Stack Constants

pub const limits = @import("limits.zig");

pub const stack_size = limits.stack_size;
pub const stack_pages = limits.stack_pages;
pub const guard_pages = limits.guard_pages;
pub const slot_pages = limits.slot_pages;
pub const slot_size = limits.slot_size;
pub const area_base = limits.area_base;
pub const area_size = limits.area_size;
pub const max_slots = limits.max_slots;
pub const cache_target = limits.cache_target;
