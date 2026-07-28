//! PIT Initialization

const io = @import("asm").io;

const constants = @import("mirai").drivers.constants;

const limits = constants.pit.limits;

pub fn init(frequency: u32) void {
    const divisor: u16 = @truncate(limits.BASE_FREQUENCY / frequency);

    io.port.writeByte(limits.COMMAND, limits.MODE_SQUARE_WAVE);
    io.port.writeByte(limits.CHANNEL0_DATA, @truncate(divisor));
    io.port.writeByte(limits.CHANNEL0_DATA, @truncate(divisor >> @bitSizeOf(u8)));
}

pub fn initDefault() void {
    init(limits.TARGET_FREQUENCY);
}
