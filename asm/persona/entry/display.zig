//! Adapt The Persona Stack For The Display Driver

const instructions = @import("personaasm").strings.entry.display;

pub export fn display_entry() linksection(instructions.SECTION) callconv(.naked) void {
    asm volatile (instructions.ENTRY ::: .{ .memory = true });
}
