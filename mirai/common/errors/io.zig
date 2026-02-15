//! I/O Errors - Input/output related errors

/// Errors related to I/O operations
pub const IoError = error{
    /// Invalid attachment
    InvalidAttachment,
    /// No more attachments available
    TooManyAttachments,
    /// View operation failed
    ViewFailed,
    /// Mark operation failed
    MarkFailed,
    /// Invalid device
    InvalidDevice,
    /// Cannot view from device
    CannotView,
    /// Cannot mark to device
    CannotMark,
    /// Bad pointer
    BadPointer,
    /// Buffer too small
    BufferTooSmall,
    /// Unknown device
    UnknownDevice,
    /// Letter send failed
    SendFailed,
};
