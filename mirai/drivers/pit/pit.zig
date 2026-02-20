//! PIT (Programmable Interval Timer) Driver

const io = @import("../../asm/io.zig");
const pit = @import("../../common/constants/pit.zig");

pub fn init() void {
    // 100 Hz for stable operation
    const command = pit.SELECT_CHANNEL_0 | pit.ACCESS_LOHI | pit.MODE_RATE_GENERATOR;
    io.out_byte(pit.COMMAND, command);
    io.out_byte(pit.CHANNEL_0, @truncate(pit.DIVISOR_100HZ));
    io.out_byte(pit.CHANNEL_0, @truncate(pit.DIVISOR_100HZ >> 8));
}
