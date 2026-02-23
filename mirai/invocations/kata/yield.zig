//! Yield invocation - Voluntarily give up CPU time to Sensei

const handler = @import("../handler.zig");
const kata_mod = @import("../../kata/kata.zig");
const result = @import("../../utils/types/result.zig");
const sensei = @import("../../kata/sensei/sensei.zig");

pub fn invoke(ctx: *handler.InvocationContext) void {
    const kata = sensei.get_current_kata() orelse return result.set_error(ctx);

    kata.state = kata_mod.State.Alive;

    if (!sensei.is_in_queue(kata)) {
        sensei.enqueue_kata(kata);
    }

    sensei.schedule();

    result.set_ok(ctx);
}
