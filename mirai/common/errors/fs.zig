//! Filesystem Errors - AFS and storage related errors

/// Errors related to filesystem operations
pub const FsError = error{
    /// Unit or stack not found
    NotFound,
    /// Location is invalid
    InvalidLocation,
    /// Not a stack
    NotAStack,
    /// Not a unit
    NotAUnit,
    /// Stack is not empty
    StackNotEmpty,
    /// Unit already exists
    AlreadyExists,
    /// Filesystem is full
    NoSpace,
    /// Filesystem is read-only
    ReadOnly,
    /// Disk I/O error
    DiskError,
    /// Filesystem corruption detected
    Corrupted,
    /// Cannot create unit
    CannotCreate,
};
