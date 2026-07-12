//! FAT32 Location Errors

pub const LocationError = error{
    NotFound,
    NotAStack,
    InvalidLocation,
};
