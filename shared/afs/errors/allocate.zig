//! AFS Allocation Errors

pub const AllocationError = error{
    OutOfSpace,
    InvalidCell,
};
