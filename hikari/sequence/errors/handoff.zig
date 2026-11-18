//! Hikari Handoff Errors

pub const HandoffError = error{
    AllocationFailed,
    ReleaseFailed,
    InvalidState,
    InvalidMemoryMap,
    ExitFailed,
};
