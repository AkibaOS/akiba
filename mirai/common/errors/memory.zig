//! Memory Errors - Memory management related errors

/// Errors related to memory management
pub const MemoryError = error{
    /// Out of physical memory
    OutOfMemory,
    /// Invalid address
    InvalidAddress,
    /// Page not present
    PageNotPresent,
    /// Allocation failed
    AllocationFailed,
    /// Address not aligned
    NotAligned,
    /// Permission denied
    PermissionDenied,
};
