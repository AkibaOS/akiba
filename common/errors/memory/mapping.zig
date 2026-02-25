//! Memory Mapping Errors

pub const MappingError = error{
    InvalidAddress,
    AddressNotAligned,
    RegionOverlap,
    PermissionDenied,
    PageTableAllocationFailed,
    AlreadyMapped,
    NotMapped,
};
