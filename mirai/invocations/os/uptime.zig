//! UPTIME invocation - Get seconds since boot

const handler = @import("../handler.zig");
const result = @import("../../utils/types/result.zig");
const sensei = @import("../../kata/sensei/sensei.zig");
const time = @import("../../common/constants/time.zig");

pub fn invoke(ctx: *handler.InvocationContext) void {
    const ticks = sensei.get_tick_count();
    const seconds = ticks / time.TICKS_PER_SECOND;
    result.set_value(ctx, seconds);
}
