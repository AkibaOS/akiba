//! TSS Stack Operations

pub const allocate = @import("allocate.zig");

pub const allocate_kernel_stack = allocate.allocate_kernel_stack;
pub const allocate_ist_stack = allocate.allocate_ist_stack;
pub const free_stack = allocate.free_stack;
