//! Thread Ownership Errors

pub const OwnershipError = error{
    InvalidOwner,
    InvalidThread,
    InvalidState,
    NotInitialized,
    InUse,
};
