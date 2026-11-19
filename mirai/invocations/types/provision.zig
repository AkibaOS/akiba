//! Private Provisioner Commands, Not The Public Binary Launch API

pub const Operation = enum(u64) {
    Begin = 0,
    Abort = 1,
    Allocate = 2,
    Load = 3,
    Seal = 4,
    Start = 5,
};

pub const Protection = enum(u64) {
    ReadOnly = 0,
    ReadWrite = 1,
    ReadExecute = 2,
};

pub const Load = extern struct {
    Destination: u64,
    Source: u64,
    Length: u64,
};

pub const Start = extern struct {
    Entry: u64,
    StackBase: u64,
    StackLength: u64,
    Startup: u64,
};
