//! Memory Allocation Errors

pub const AllocationError = error{
    OutOfMemory,
    InvalidSize,
    InvalidAlignment,
    RegionExhausted,
    ZoneExhausted,
};
