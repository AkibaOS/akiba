//! Native Persona Stack And Register Adapter

const instructions = @import("personaasm").strings.entry.native;

pub export fn persona_entry() linksection(instructions.SECTION) callconv(.naked) void {
    asm volatile (instructions.START ::: .{ .memory = true });
}

pub export fn persona_invoke() callconv(.naked) void {
    asm volatile (instructions.INVOKE ::: .{ .memory = true });
}
