//! PIT Initialization

const constants = @import("constants/constants.zig");
const asm_io = @import("../../asm/io/io.zig");

pub fn init(frequency: u32) void {
    const divisor: u16 = @truncate(constants.base_frequency / frequency);

    asm_io.write_byte(constants.command, constants.mode_square_wave);
    asm_io.write_byte(constants.channel0_data, @truncate(divisor));
    asm_io.write_byte(constants.channel0_data, @truncate(divisor >> 8));
}

pub fn init_default() void {
    init(constants.target_frequency);
}
