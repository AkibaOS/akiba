//! Unpublished Bootstrap Image Ownership

const Kata = @import("mirai").kata.types.kata.Kata;
const Thread = @import("mirai").thread.types.thread.Thread;

pub const Options = struct {
    StackBase: u64,
    StackPages: u64,
    Argument: u64 = 0,
    Startup: ?Startup = null,
};

pub const Startup = struct {
    Identity: []const u8,
    Parameters: []const u8,
};

pub const StartupSpan = struct {
    Start: u64,
    End: u64,
};

pub const Prepared = struct {
    ID: u64,
    Owner: *Kata,
    Thread: *Thread,
    ThreadGeneration: u64,
};
