//! AFS Block I/O Errors

pub const BlockError = error{
    ReadFailed,
    WriteFailed,
    OutOfBounds,
    InvalidCell,
    DeviceError,
    NotSupported,
};
