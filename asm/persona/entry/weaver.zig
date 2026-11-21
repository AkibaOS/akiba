//! Adapt The Persona Stack For Weaver

const instructions = @import("personaasm").strings.entry.weaver;

pub export fn weaver_entry() linksection(instructions.SECTION) callconv(.naked) void {
    asm volatile (instructions.ENTRY ::: .{ .memory = true });
}
