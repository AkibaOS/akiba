//! Adapt The Persona Stack For The Keyboard Driver

const instructions = @import("personaasm").strings.entry.keyboard;

pub export fn keyboard_entry() linksection(instructions.SECTION) callconv(.naked) void {
    asm volatile (instructions.ENTRY ::: .{ .memory = true });
}
