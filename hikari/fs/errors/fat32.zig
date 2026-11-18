//! Hikari FAT32 Adapter Errors

pub const ReadError = error{
    AllocationFailed,
    InvalidBootSector,
    InvalidChain,
    InvalidCluster,
    InvalidPartition,
    MediaChanged,
    NotAStack,
    NotFound,
    ReadFailed,
    ReaderClosed,
    UnitTooLarge,
};
