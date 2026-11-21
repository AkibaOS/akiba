//! Compiler PIE For Persona Shared Library Execution

const elf = @import("tests").fixtures.constants.elf.layout;
const entry = @import("fixtureasm").entry;
const inputs = @import("tests").fixtures.constants.weaver;
const invocation = @import("fixtureasm").invocation;
const labels = @import("tests").fixtures.strings.weaver;
const service = @import("servicefixture");
const types = @import("tests").fixtures.types.weaver;

extern var linked_counter: u64;
extern fn linked_step() callconv(.c) u64;

comptime {
    _ = entry.akiba_fixture_start;
}

export fn akiba_fixture_main(argument: u64) callconv(.{ .x86_64_sysv = .{} }) noreturn {
    if (argument != 0 and service.recognizes(argument)) service.run(argument);
    if (argument != 0 and !verifyStartup(argument)) invocation.exit(inputs.REJECTED_STARTUP_RESULT);
    const result = linked_step();
    const startup_score = if (argument == 0) 0 else inputs.VERIFIED_STARTUP_RESULT;
    invocation.exit(result +% linked_counter +% startup_score);
}

fn verifyStartup(address: u64) bool {
    const header: *const volatile [3]u64 = @ptrFromInt(address);
    if (header[0] != 1) return false;
    if (header[1] == labels.INSTALLED_IDENTITY.len and header[2] == inputs.INSTALLED_PARAMETERS.len) return verifyInstalled(address);
    if (address != inputs.STARTUP_ADDRESS or header[1] != labels.IDENTITY.len or header[2] != inputs.PARAMETER_COUNT) return false;
    const payload: [*]const volatile u8 = @ptrFromInt(address + elf.STARTUP_HEADER_BYTES);
    for (labels.IDENTITY, 0..) |expected, index| if (payload[index] != expected) return false;
    const parameters = payload + labels.IDENTITY.len;
    const mode = parameters[0];
    if (mode != inputs.PARAMETER_BYTE and mode != inputs.HOLD_PARAMETER) return false;
    for (1..inputs.PARAMETER_COUNT - 1) |index| if (parameters[index] != inputs.PARAMETER_BYTE) return false;
    if (parameters[inputs.PARAMETER_COUNT - 1] != inputs.PARAMETER_LAST) return false;
    return mode != inputs.HOLD_PARAMETER or awaitRelease();
}

fn verifyInstalled(address: u64) bool {
    const payload: [*]const volatile u8 = @ptrFromInt(address + elf.STARTUP_HEADER_BYTES);
    for (labels.INSTALLED_IDENTITY, 0..) |expected, index| if (payload[index] != expected) return false;
    const parameters = payload + labels.INSTALLED_IDENTITY.len;
    for (inputs.INSTALLED_PARAMETERS, 0..) |expected, index| if (parameters[index] != expected) return false;
    return true;
}

fn awaitRelease() bool {
    var header: types.Header = undefined;
    const result = invocation.call(inputs.RECEIVE, 0, 0, @intFromPtr(&header), 0);
    return result.Status == 0 and result.Value == 0 and header.Type == inputs.RELEASE_TYPE and header.ReplyTicket == 0;
}
