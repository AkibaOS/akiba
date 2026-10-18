//! Kata Ownership Errors

pub const OwnershipError = error{
    InvalidKata,
    InvalidState,
    InUse,
};
