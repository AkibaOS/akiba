//! Bounded Bundle Source Read Errors

pub const ReadError = error{ OutOfMemory, ReadFailed, MissingStack, TooLarge };
