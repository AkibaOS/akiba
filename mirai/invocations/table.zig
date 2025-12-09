//! AI Table - Akiba Invocation Table
//! Implements individual invocations that Persona programs can call

const handler = @import("handler.zig");
const kata_mod = @import("../kata/kata.zig");
const sensei = @import("../kata/sensei.zig");
const serial = @import("../drivers/serial.zig");

const InvocationContext = handler.InvocationContext;

// Invocation: exit - Terminate current Kata
// Arguments: RDI = exit code
pub fn invoke_exit(context: *InvocationContext) void {
    const exit_code = context.rdi;

    serial.print("Kata exit with code: ");
    serial.print_hex(exit_code);
    serial.print("\n");

    // Get current Kata
    if (sensei.get_current_kata()) |current_kata| {
        serial.print("Dissolving Kata ");
        serial.print_hex(current_kata.id);
        serial.print("\n");

        // Mark as dissolved
        kata_mod.dissolve_kata(current_kata.id);

        // Trigger scheduler to pick next Kata
        sensei.schedule();

        // If schedule() returns (no other Kata to run), halt
        serial.print("No more Kata to run, halting\n");
        while (true) {
            asm volatile ("hlt");
        }
    }
}
