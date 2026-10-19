//! Ring Three Transfer Types

pub const Continuation = *const fn (*anyopaque) callconv(.{ .x86_64_sysv = .{} }) noreturn;

pub const Entry = extern struct {
    RIP: u64,
    RSP: u64,
    RFLAGS: u64,
    CS: u64,
    SS: u64,
    Argument: u64,
    FPUAddress: u64,
};
