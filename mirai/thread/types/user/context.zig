//! User Execution And Fault State

pub const User = struct {
    RIP: u64 = 0,
    RSP: u64 = 0,
    StackBase: u64 = 0,
    StackTop: u64 = 0,
    Argument: u64 = 0,
    Faulted: bool = false,
    FaultVector: u64 = 0,
    FaultAddress: u64 = 0,
    FaultCode: u64 = 0,
    FaultRIP: u64 = 0,
    FaultRSP: u64 = 0,
};
