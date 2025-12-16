//! Wait invocation - Wait for child Kata to exit

const handler = @import("handler.zig");
const serial = @import("../drivers/serial.zig");
const sensei = @import("../kata/sensei.zig");
const kata_mod = @import("../kata/kata.zig");

pub fn invoke(ctx: *handler.InvocationContext) void {
    const target_id = @as(u32, @truncate(ctx.rdi));

    serial.print("Invocation: wait\n");
    serial.print("  Waiting for Kata: ");
    serial.print_hex(target_id);
    serial.print("\n");

    // Find the target Kata
    const target = kata_mod.get_kata(target_id) orelse {
        serial.print("  Kata not found\n");
        ctx.rax = @as(u64, @bitCast(@as(i64, -1)));
        return;
    };

    // If already exited, return immediately
    if (target.state == .Dissolved) {
        serial.print("  Kata already exited with code: ");
        serial.print_hex(target.exit_code);
        serial.print("\n");
        ctx.rax = target.exit_code;
        return;
    }

    // Mark current Kata as waiting
    if (sensei.get_current_kata()) |current| {
        current.state = .Waiting;
        current.waiting_for = target_id;
    }

    // Schedule another Kata
    sensei.schedule();

    // When we resume, the target has exited
    const exit_code = target.exit_code;
    serial.print("  Kata exited with code: ");
    serial.print_hex(exit_code);
    serial.print("\n");

    ctx.rax = exit_code;
}
