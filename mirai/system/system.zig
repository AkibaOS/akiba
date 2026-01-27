//! Akiba OS System Module
//! Central import point for all system-wide constants, limits, and utilities

// System constants (memory layout, addresses, architectural constants)
pub const constants = @import("constants.zig");

// System limits (process limits, buffer sizes, validation)
pub const limits = @import("limits.zig");

// Re-export commonly used constants for convenience
pub const PAGE_SIZE = constants.PAGE_SIZE;
pub const HIGHER_HALF_START = constants.HIGHER_HALF_START;
pub const USER_SPACE_MAX = limits.USER_SPACE_MAX;
pub const USER_SPACE_MIN = limits.USER_SPACE_MIN;

// Re-export validation helpers
pub const is_valid_user_pointer = limits.is_valid_user_pointer;
pub const is_userspace_address = limits.is_userspace_address;
pub const is_kernel_address = limits.is_kernel_address;
pub const is_userspace_range = limits.is_userspace_range;

// Re-export memory helpers
pub const align_down = constants.align_down;
pub const align_up = constants.align_up;
pub const pages_for_size = constants.pages_for_size;
pub const is_page_aligned = constants.is_page_aligned;
