//! Invocation Buffer Argument Errors

pub const ArgumentError = error{
    InvalidAddress,
    TooLarge,
};
