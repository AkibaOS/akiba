//! TSS Setup Errors

const allocation = @import("common").errors.memory.allocation;

pub const CoreError = allocation.AllocationError || error{TooManyCores};
