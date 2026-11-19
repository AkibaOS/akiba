//! Persona Invocation Machine State Fixtures

const Floating = @import("tests").guest.types.context.Floating;

pub const Registers = extern struct {
    RBX: u64 = 0,
    RBP: u64 = 0,
    RCX: u64 = 0,
    RSI: u64 = 0,
    R8: u64 = 0,
    R9: u64 = 0,
    R10: u64 = 0,
    R11: u64 = 0,
    R12: u64 = 0,
    R13: u64 = 0,
    R14: u64 = 0,
    R15: u64 = 0,
};

pub const Snapshot = extern struct {
    Status: u64 = 0,
    Value: u64 = 0,
    Input: u64 = 0,
    Stack: u64 = 0,
    Flags: u64 = 0,
    Registers: Registers = .{},
    Float: Floating = .{},
};

pub const Frame = extern struct {
    FirstSeed: Snapshot,
    SecondSeed: Snapshot,
    Query: Snapshot = .{},
    Yield: Snapshot = .{},
    Finished: u64 = 0,
};
