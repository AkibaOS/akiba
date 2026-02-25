//! Memory Errors

pub const allocation = @import("allocation.zig");
pub const mapping = @import("mapping.zig");

pub const AllocationError = allocation.AllocationError;
pub const MappingError = mapping.MappingError;
