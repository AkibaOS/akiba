//! I/O errors

pub const IoError = error{
    InvalidAttachment,
    TooManyAttachments,
    ViewFailed,
    MarkFailed,
    InvalidDevice,
    CannotView,
    CannotMark,
    BadPointer,
    BufferTooSmall,
    UnknownDevice,
    SendFailed,
};
