//! Hikari Handoff Errors

pub const HandoffError = error{
    AllocationFailed,
    InvalidMemoryMap,
    ExitFailed,
};
