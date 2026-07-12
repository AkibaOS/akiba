//! Hikari FAT32 Adapter Errors

pub const ReadError = error{
    InvalidBootSector,
    InvalidFsInfo,
    ReadFailed,
    AllocationFailed,
    NotFound,
    NotAStack,
    InvalidCluster,
    UnitTooLarge,
};
