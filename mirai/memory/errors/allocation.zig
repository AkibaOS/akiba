//! General Kernel Allocation Errors

const common = @import("common");

pub const AllocationError = common.errors.memory.allocation.AllocationError || common.errors.memory.mapping.MappingError;
