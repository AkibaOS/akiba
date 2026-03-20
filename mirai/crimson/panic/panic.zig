//! Panic Operations

pub const collapse_module = @import("collapse.zig");
pub const gather = @import("gather.zig");
pub const halt = @import("halt.zig");

pub const collapse = collapse_module.collapse;
pub const collapse_with_context = collapse_module.collapse_with_context;
pub const is_collapsing = collapse_module.is_collapsing;

pub const capture_current_context = gather.capture_current_context;
pub const capture_float_state = gather.capture_float_state;
pub const capture_debug_state = gather.capture_debug_state;
pub const get_current_cpu = gather.get_current_cpu;
pub const get_uptime_ticks = gather.get_uptime_ticks;

pub const halt_all = halt.halt_all;
pub const halt_current = halt.halt_current;
