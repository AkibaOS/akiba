//! Retained User Fault Details

pub const Fault = struct {
    Vector: u64,
    Code: u64,
    Address: u64,
    Instruction: u64,
    StackPointer: u64,
};
