//! Adapt The Persona Stack For The AFS Driver

const instructions = @import("personaasm").strings.entry.afs;

pub export fn afs_entry() linksection(instructions.SECTION) callconv(.naked) void {
    asm volatile (instructions.ENTRY ::: .{ .memory = true });
}
