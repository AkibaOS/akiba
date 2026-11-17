//! AFS Allocation Errors

pub const AllocationError = error{
    InvalidBitmap,
    InvalidCell,
    OutOfSpace,
};
