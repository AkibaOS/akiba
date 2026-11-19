//! Compiler PIE For Persona Shared Library Execution

const entry = @import("fixtureasm").entry;
const invocation = @import("fixtureasm").invocation;

extern var linked_counter: u64;
extern fn linked_step() callconv(.c) u64;

comptime {
    _ = entry.akiba_fixture_start;
}

export fn akiba_fixture_main(_: u64) callconv(.{ .x86_64_sysv = .{} }) noreturn {
    const result = linked_step();
    invocation.exit(result +% linked_counter);
}
