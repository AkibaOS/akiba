//! ELF Reading And Image Plan Errors

pub const ImageError = error{
    InvalidHeader,
    InvalidProgramHeaders,
    NoLoadableSegments,
    UnsupportedArchitecture,
    UnsupportedImage,
    UnsupportedSegment,
    InvalidSegment,
    SegmentOverlap,
    PermissionConflict,
    ImageTooLarge,
    InvalidEntryPoint,
    InvalidPolicy,
};
