//! Hikari Page Table Setup Errors

pub const SetupError = error{
    AllocationFailed,
    InvalidMapping,
};
