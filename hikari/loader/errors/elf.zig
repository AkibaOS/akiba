//! Hikari ELF Load Errors

pub const LoadError = error{
    InvalidElfHeader,
    InvalidProgramHeaders,
    InvalidSegment,
    InvalidEntryPoint,
    UnsupportedImageLayout,
    UnsupportedArchitecture,
    UnsupportedElfType,
    NoLoadableSegments,
    TooManySegments,
    ImageTooLarge,
    AllocationFailed,
    SegmentOverlap,
};
