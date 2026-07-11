//! PIT Constants

pub const channel0_data: u16 = 0x40;
pub const channel1_data: u16 = 0x41;
pub const channel2_data: u16 = 0x42;
pub const command: u16 = 0x43;

pub const base_frequency: u32 = 1193182;
pub const target_frequency: u32 = 1000;

pub const mode_square_wave: u8 = 0x36;
pub const mode_rate_generator: u8 = 0x34;

pub const irq: u4 = 0;
pub const vector: u8 = 32;
