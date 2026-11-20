//! Kernel Thread Entry Type

pub const Entry = *const fn (?*anyopaque) callconv(.{ .x86_64_sysv = .{} }) noreturn;
