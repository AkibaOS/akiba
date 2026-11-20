//! Kernel Activation Continuation Type

pub const Continuation = *const fn (*const anyopaque) callconv(.{ .x86_64_sysv = .{} }) noreturn;
