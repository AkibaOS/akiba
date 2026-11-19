//! Small Compiler ELF For Real Staged Launch Verification

const std = @import("std");

const entry = @import("fixtureasm").entry;
const invocation = @import("fixtureasm").invocation;
const values = @import("fixture").constants.values;

comptime {
    _ = entry.akiba_fixture_start;
}

export fn akiba_fixture_main(argument: u64) callconv(.{ .x86_64_sysv = .{} }) noreturn {
    if (argument < values.PAGE_SIZE or argument > values.USER_LAST - values.PAGE_SIZE or argument % values.PAGE_SIZE != 0)
        invocation.exit(values.BAD_ARGUMENT);
    const words: [*]const volatile u64 = @ptrFromInt(argument);
    const body: [*]const volatile u8 = @ptrFromInt(argument + values.STARTUP_FIELDS * @sizeOf(u64));
    if (words[0] != values.STARTUP_VERSION or words[1] != 1 or words[2] != 1 or
        body[0] != values.PROVISION_IDENTITY or body[1] != values.PROVISION_PARAMETER)
        invocation.exit(values.BAD_ARGUMENT);
    invocation.exit(values.PROVISION_RESULT);
}

pub fn panic(_: []const u8, _: ?*std.builtin.StackTrace, _: ?usize) noreturn {
    invocation.exit(values.BAD_PANIC);
}
