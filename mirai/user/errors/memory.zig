//! Owned User Memory Error Set

const common = @import("common");

pub const UserError = error{
    InvalidOwner,
    InvalidUserRange,
    CopyTooLarge,
    OwnershipCapacity,
    AlreadyOwned,
    NotOwned,
    InvalidOwnedMapping,
    InvalidPhysmap,
    SealedPage,
    OwnerInUse,
} || common.errors.memory.allocation.AllocationError || common.errors.memory.mapping.MappingError;
