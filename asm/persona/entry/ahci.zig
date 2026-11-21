//! Adapt The Persona Stack For The AHCI Driver

const instructions = @import("personaasm").strings.entry.ahci;

pub export fn ahci_entry() linksection(instructions.SECTION) callconv(.naked) void {
    asm volatile (instructions.ENTRY ::: .{ .memory = true });
}
