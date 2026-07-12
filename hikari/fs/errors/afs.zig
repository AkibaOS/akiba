//! Hikari AFS Adapter Errors

pub const BTreeError = error{
    ReadFailed,
    InvalidNode,
    InvalidHeader,
    KeyNotFound,
    TreeEmpty,
    AllocationFailed,
};

pub const ReadError = error{
    InvalidVolumeHeader,
    ReadFailed,
    AllocationFailed,
    NotFound,
    NotAStack,
    UnitTooLarge,
    InvalidSpan,
    BTreeError,
};
