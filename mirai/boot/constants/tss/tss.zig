//! TSS Constants

pub const limits = @import("limits.zig");

pub const tss_size = limits.tss_size;
pub const ist_count = limits.ist_count;
pub const ist_double_fault = limits.ist_double_fault;
pub const ist_nmi = limits.ist_nmi;
pub const ist_machine_check = limits.ist_machine_check;
pub const ist_debug = limits.ist_debug;
pub const default_stack_size = limits.default_stack_size;
pub const interrupt_stack_size = limits.interrupt_stack_size;
pub const max_cores = limits.max_cores;
