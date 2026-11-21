//! AFS Read Errors

pub const ReadError = error{
    ReadFailed,
    UnitTooLarge,
    InvalidSpan,
    InvalidOffset,
    BufferTooSmall,
    InvalidVolumeHeader,
    InvalidCatalog,
    InvalidIdentity,
};
