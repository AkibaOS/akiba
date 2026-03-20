//! Exception Raise

pub const hardware = @import("hardware.zig");
pub const software = @import("software.zig");
pub const resource = @import("resource.zig");
pub const guard = @import("guard.zig");

pub const raise_from_vector = hardware.raise_from_vector;
pub const raise_from_interrupt = hardware.raise_from_interrupt;

pub const raise_assertion = software.raise_assertion;
pub const raise_abort = software.raise_abort;
pub const raise_user_defined = software.raise_user_defined;

pub const raise_memory_limit = resource.raise_memory_limit;
pub const raise_cpu_limit = resource.raise_cpu_limit;
pub const raise_file_limit = resource.raise_file_limit;

pub const raise_port_guard = guard.raise_port_guard;
pub const raise_file_guard = guard.raise_file_guard;
pub const raise_memory_guard = guard.raise_memory_guard;
