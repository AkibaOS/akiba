//! Disk Image Errors

pub const ImageError = error{
    EspTooSmall,
    ImageSizeMismatch,
    OutputInsideSource,
    SourceChanged,
};
