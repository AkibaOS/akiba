//! AFS Location Errors

pub const LocationError = error{
    NotFound,
    NotAStack,
    InvalidLocation,
    BTreeError,
};
