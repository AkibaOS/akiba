//! Kata Errors - Kata-related errors

/// Errors related to kata management
pub const KataError = error{
    /// No free kata slots available
    TooManyKatas,
    /// Kata ID not found
    KataNotFound,
    /// Invalid kata state for operation
    InvalidState,
    /// Kata is not a child of current kata
    NotChild,
    /// Cannot wait for self
    WaitingSelf,
};
