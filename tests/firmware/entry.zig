//! Dedicated Firmware Regression Executable

const std = @import("std");

const run = @import("tests").firmware.run;

pub fn main() void {
    run.main();
}

pub fn panic(message: []const u8, stack_trace: ?*std.builtin.StackTrace, return_address: ?usize) noreturn {
    run.panic(message, stack_trace, return_address);
}
