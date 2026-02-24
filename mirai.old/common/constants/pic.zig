//! PIC constants

pub const MASTER_CMD: u16 = 0x20;
pub const MASTER_DATA: u16 = 0x21;
pub const SLAVE_CMD: u16 = 0xA0;
pub const SLAVE_DATA: u16 = 0xA1;

pub const ICW1_INIT: u8 = 0x11;
pub const ICW4_8086: u8 = 0x01;

pub const MASTER_OFFSET: u8 = 0x20;
pub const SLAVE_OFFSET: u8 = 0x28;

pub const MASTER_CASCADE: u8 = 0x04;
pub const SLAVE_CASCADE: u8 = 0x02;

pub const MASK_TIMER_KEYBOARD: u8 = 0xFC;
pub const MASK_ALL: u8 = 0xFF;

pub const EOI: u8 = 0x20;
