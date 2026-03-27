//! PIC I/O Ports

pub const pic1_command: u16 = 0x20;
pub const pic1_data: u16 = 0x21;
pub const pic2_command: u16 = 0xA0;
pub const pic2_data: u16 = 0xA1;

pub const icw1_icw4: u8 = 0x01;
pub const icw1_init: u8 = 0x10;
pub const icw4_8086: u8 = 0x01;

pub const eoi: u8 = 0x20;

pub const vector_offset_master: u8 = 32;
pub const vector_offset_slave: u8 = 40;
