//! PIT Constants

const common = @import("common");

const vectors = common.constants.interrupts.vectors;

pub const CHANNEL0_DATA: u16 = 0x40;
pub const CHANNEL1_DATA: u16 = 0x41;
pub const CHANNEL2_DATA: u16 = 0x42;
pub const COMMAND: u16 = 0x43;

pub const BASE_FREQUENCY: u32 = 1193182;
pub const TARGET_FREQUENCY: u32 = 1000;

pub const MODE_SQUARE_WAVE: u8 = 0x36;
pub const MODE_RATE_GENERATOR: u8 = 0x34;

pub const IRQ: u4 = 0;
pub const VECTOR: u8 = vectors.VECTOR_OFFSET + @as(u8, IRQ);
