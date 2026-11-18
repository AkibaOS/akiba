//! PIT Initialization

const std = @import("std");

const constants = @import("mirai").drivers.constants;
const io = @import("asm").io;

const limits = constants.pit.limits;

pub fn initDefault() void {
    const divisor: u16 = limits.BASE_FREQUENCY / limits.TARGET_FREQUENCY;
    comptime std.debug.assert(divisor >= limits.SQUARE_WAVE_MINIMUM_DIVISOR);
    io.port.writeByte(limits.COMMAND, limits.MODE_SQUARE_WAVE);
    io.port.writeByte(limits.CHANNEL0_DATA, @truncate(divisor));
    io.port.writeByte(limits.CHANNEL0_DATA, @truncate(divisor >> @bitSizeOf(u8)));
}
