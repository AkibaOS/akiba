//! Corpse Operations

pub const generate_module = @import("generate.zig");
pub const inspect = @import("inspect.zig");
pub const release = @import("release.zig");

pub const generate = generate_module.generate;

pub const inspect_corpse = inspect.inspect;
pub const get_context = inspect.get_context;
pub const get_stack_snapshot = inspect.get_stack_snapshot;
pub const get_memory_snapshot = inspect.get_memory_snapshot;
pub const get_memory_snapshot_address = inspect.get_memory_snapshot_address;
pub const get_fault_address = inspect.get_fault_address;
pub const get_timestamp = inspect.get_timestamp;

pub const allocate = release.allocate;
pub const release_corpse = release.release;
pub const release_all_for_kata = release.release_all_for_kata;
pub const get_active_count = release.get_active_count;
