//! Hikari ELF Load Errors

pub const LoadError = error{
    InvalidElfHeader,
    UnsupportedArchitecture,
    UnsupportedElfType,
    NoLoadableSegments,
    TooManySegments,
    AllocationFailed,
    SegmentOverlap,
};
