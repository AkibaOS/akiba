//! Copied Kata Completion ABI

pub const Kind = enum(u64) {
    Completed = 0,
    Exited = 1,
    Faulted = 2,
};

pub const Record = extern struct {
    Kind: Kind = .Completed,
    Result: u64 = 0,
    Vector: u64 = 0,
    Code: u64 = 0,
    Address: u64 = 0,
    Instruction: u64 = 0,
    StackPointer: u64 = 0,
};
