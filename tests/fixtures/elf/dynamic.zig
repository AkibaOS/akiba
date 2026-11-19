//! Compiler PIE For Persona Shared Library Execution

const elf = @import("tests").fixtures.constants.elf;
const entry = @import("fixtureasm").entry;
const inputs = @import("tests").fixtures.constants.weaver;
const invocation = @import("fixtureasm").invocation;
const labels = @import("tests").fixtures.strings.weaver;

extern var linked_counter: u64;
extern fn linked_step() callconv(.c) u64;

comptime {
    _ = entry.akiba_fixture_start;
}

export fn akiba_fixture_main(argument: u64) callconv(.{ .x86_64_sysv = .{} }) noreturn {
    if (argument != 0 and !verifyStartup(argument)) invocation.exit(inputs.REJECTED_STARTUP_RESULT);
    const result = linked_step();
    const startup_score = if (argument == 0) 0 else inputs.VERIFIED_STARTUP_RESULT;
    invocation.exit(result +% linked_counter +% startup_score);
}

fn verifyStartup(address: u64) bool {
    if (address != inputs.STARTUP_ADDRESS) return false;
    const header: *const volatile [3]u64 = @ptrFromInt(address);
    if (header[0] != 1 or header[1] != labels.IDENTITY.len or header[2] != inputs.PARAMETER_COUNT) return false;
    const payload: [*]const volatile u8 = @ptrFromInt(address + elf.STARTUP_HEADER_BYTES);
    for (labels.IDENTITY, 0..) |expected, index| if (payload[index] != expected) return false;
    const parameters = payload + labels.IDENTITY.len;
    for (0..inputs.PARAMETER_COUNT - 1) |index| if (parameters[index] != inputs.PARAMETER_BYTE) return false;
    return parameters[inputs.PARAMETER_COUNT - 1] == inputs.PARAMETER_LAST;
}
