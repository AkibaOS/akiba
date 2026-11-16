//! Kata Completion Access Errors

pub const CompletionError = error{
    InvalidCaller,
    InvalidTarget,
    NotOwner,
    NotReady,
    ObserverCapacity,
};
