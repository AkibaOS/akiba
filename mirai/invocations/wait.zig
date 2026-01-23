//! Wait invocation - Wait for child Kata to exit

const handler = @import("handler.zig");
const serial = @import("../drivers/serial.zig");
const sensei = @import("../kata/sensei.zig");
const kata_mod = @import("../kata/kata.zig");

pub fn invoke(ctx: *handler.InvocationContext) void {
    const target_id = @as(u32, @truncate(ctx.rdi));

    // Find the target Kata
    const target = kata_mod.get_kata(target_id) orelse {
        ctx.rax = @as(u64, @bitCast(@as(i64, -1)));
        return;
    };

    // If already exited, return immediately
    if (target.state == .Dissolved) {
        ctx.rax = target.exit_code;
        return;
    }

    // Target is still running - block this kata
    const current = sensei.get_current_kata() orelse {
        ctx.rax = @as(u64, @bitCast(@as(i64, -1)));
        return;
    };

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
