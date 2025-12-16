//! Kata (process) control functions

const sys = @import("sys.zig");

pub fn exit(code: u64) noreturn {
    _ = sys.syscall1(.exit, code);
    unreachable;
}

// Future: spawn, wait, etc.
