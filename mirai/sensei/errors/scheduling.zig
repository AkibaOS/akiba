//! Scheduling Errors

pub const SchedulingError = error{
    NotInitialized,
    InvalidThread,
    AlreadyManaged,
    NotManaged,
    InUse,
    UnsafeContext,
    CapacityReached,
    InvalidQueue,
    InvalidState,
};
