//! Serial Port Constants

pub const COM1: u16 = 0x3F8;
pub const COM2: u16 = 0x2F8;
pub const COM3: u16 = 0x3E8;
pub const COM4: u16 = 0x2E8;

pub const DEFAULT_PORT: u16 = COM1;

pub const BAUD_RATE_115200: u16 = 1;
pub const BAUD_RATE_57600: u16 = 2;
pub const BAUD_RATE_38400: u16 = 3;
pub const BAUD_RATE_19200: u16 = 6;
pub const BAUD_RATE_9600: u16 = 12;

pub const DEFAULT_BAUD_DIVISOR: u16 = BAUD_RATE_115200;
