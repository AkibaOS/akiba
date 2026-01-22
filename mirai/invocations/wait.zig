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

    // Target is still running - block this kata
    const current = sensei.get_current_kata() orelse {
        ctx.rax = @as(u64, @bitCast(@as(i64, -1)));
        return;
    };

    serial.print("  Kata still running, blocking parent\n");
    current.state = .Waiting;
    current.waiting_for = target_id;

    // Schedule another kata
    sensei.schedule();

    // When we return here, check if target has exited
    if (target.state == .Dissolved) {
        ctx.rax = target.exit_code;
    } else {
        ctx.rax = @as(u64, @bitCast(@as(i64, -1)));
    }
}
