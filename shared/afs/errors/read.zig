//! AFS Read Errors

pub const ReadError = error{
    ReadFailed,
    UnitTooLarge,
    InvalidSpan,
    BufferTooSmall,
};
