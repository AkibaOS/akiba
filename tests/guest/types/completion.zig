//! Persona Completion Wire Test Fixtures

const Thread = @import("mirai").thread.types.thread.Thread;

pub const Record = extern struct {
    Kind: u64 = 0,
    Result: u64 = 0,
    Vector: u64 = 0,
    Code: u64 = 0,
    Address: u64 = 0,
    Instruction: u64 = 0,
    StackPointer: u64 = 0,
};

pub const Target = struct {
    ID: u64,
    Thread: *Thread,
    Stack: u64 = 0,
};
