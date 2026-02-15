//! Filesystem errors

pub const FsError = error{
    NotFound,
    InvalidLocation,
    NotAStack,
    NotAUnit,
    StackNotEmpty,
    AlreadyExists,
    NoSpace,
    ReadOnly,
    DiskError,
    Corrupted,
    CannotCreate,
};
