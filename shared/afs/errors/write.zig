//! AFS Write Errors

pub const WriteError = error{
    WriteFailed,
    OutOfSpace,
    InvalidCell,
};
