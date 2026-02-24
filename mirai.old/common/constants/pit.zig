//! PIT (Programmable Interval Timer) constants

pub const CHANNEL_0: u16 = 0x40;
pub const CHANNEL_1: u16 = 0x41;
pub const CHANNEL_2: u16 = 0x42;
pub const COMMAND: u16 = 0x43;

pub const BASE_FREQUENCY: u32 = 1193182;

// Command byte bits
pub const SELECT_CHANNEL_0: u8 = 0x00;
pub const ACCESS_LOHI: u8 = 0x30; // Low byte then high byte
pub const MODE_RATE_GENERATOR: u8 = 0x04; // Mode 2: rate generator
pub const MODE_SQUARE_WAVE: u8 = 0x06; // Mode 3: square wave

// For 1000 Hz (1ms ticks): divisor = 1193182 / 1000 = 1193
pub const DIVISOR_1000HZ: u16 = 1193;

// For 100 Hz (10ms ticks): divisor = 1193182 / 100 = 11932
pub const DIVISOR_100HZ: u16 = 11932;
