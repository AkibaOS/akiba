//! AFS Write Errors

pub const WriteError = error{
    InvalidCell,
    InvalidIdentity,
    InvalidSpan,
    OutOfSpace,
    Overflow,
    WriteFailed,
};
