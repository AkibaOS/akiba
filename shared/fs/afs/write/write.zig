//! AFS Write Operations

pub const unit = @import("unit.zig");
pub const allocate = @import("allocate.zig");
pub const stack = @import("stack.zig");

pub const write_span = unit.write_span;
pub const cells_needed = unit.cells_needed;
pub const create_channel_info = unit.create_channel_info;
pub const WriteError = unit.WriteError;

pub const AllocationMap = allocate.AllocationMap;
pub const AllocationError = allocate.AllocationError;
pub const bitmap_size = allocate.bitmap_size;

pub const create_stack_record = stack.create_stack_record;
pub const create_unit_record = stack.create_unit_record;
pub const create_index_key = stack.create_index_key;
pub const index_key_size = stack.index_key_size;
