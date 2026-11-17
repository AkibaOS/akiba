//! Test Only ELF Executable Root

const std = @import("std");

const entry = @import("fixtureasm").entry;
const execute = @import("fixture").execute;

comptime {
    _ = entry.akiba_fixture_start;
}

export fn akiba_fixture_main(argument: u64) callconv(.{ .x86_64_sysv = .{} }) noreturn {
    execute.run(argument);
}

pub fn panic(message: []const u8, stack_trace: ?*std.builtin.StackTrace, return_address: ?usize) noreturn {
    _ = message;
    _ = stack_trace;
    _ = return_address;
    execute.panic();
}
