//! Serial Port Constants

pub const com1: u16 = 0x3F8;
pub const com2: u16 = 0x2F8;
pub const com3: u16 = 0x3E8;
pub const com4: u16 = 0x2E8;

pub const default_port: u16 = com1;

pub const baud_rate_115200: u16 = 1;
pub const baud_rate_57600: u16 = 2;
pub const baud_rate_38400: u16 = 3;
pub const baud_rate_19200: u16 = 6;
pub const baud_rate_9600: u16 = 12;

pub const default_baud_divisor: u16 = baud_rate_115200;
