//! Weaver System Library Selection Errors

const DynamicError = @import("shared").elf.errors.dynamic.DynamicError;

pub const ReadError = error{ OutOfMemory, LibraryReadFailed };
pub const LibraryError = DynamicError || ReadError || error{
    InvalidLibraryName,
    LibraryNotFound,
    LibraryNameMismatch,
};
