//! Memory errors

pub const MemoryError = error{
    OutOfMemory,
    InvalidAddress,
    PageNotPresent,
    AllocationFailed,
    NotAligned,
    PermissionDenied,
};
