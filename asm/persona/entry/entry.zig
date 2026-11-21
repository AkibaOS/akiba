//! Adapt Persona Entry Stack For The Pulse Binary

const instructions = @import("personaasm").strings.entry.pulse;

pub export fn pulse_entry() linksection(instructions.SECTION) callconv(.naked) void {
    asm volatile (instructions.ENTRY ::: .{ .memory = true });
}
