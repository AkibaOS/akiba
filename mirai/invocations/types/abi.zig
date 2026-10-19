//! Invocation Register ABI Types

pub const Service = enum(u64) {
    Query = 0,
    Yield = 1,
};

pub const Query = enum(u64) {
    ABI = 0,
    Kata = 1,
};

pub const Status = enum(u64) {
    Success = 0,
    Unsupported = 1,
    InvalidArgument = 2,
    InvalidCaller = 3,
};
