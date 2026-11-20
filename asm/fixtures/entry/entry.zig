//! Test Only Machine Entry Stack Adaptation

const instructions = @import("fixtureasm").strings.entry.symbol;

pub export fn akiba_fixture_start() linksection(instructions.ENTRY_SECTION) callconv(.naked) void {
    asm volatile (instructions.ENTRY ::: .{ .memory = true });
}
