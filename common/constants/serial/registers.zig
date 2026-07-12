//! Serial Register Constants

pub const DATA_REGISTER: u16 = 0;
pub const INTERRUPT_ENABLE_REGISTER: u16 = 1;
pub const FIFO_CONTROL_REGISTER: u16 = 2;
pub const LINE_CONTROL_REGISTER: u16 = 3;
pub const MODEM_CONTROL_REGISTER: u16 = 4;
pub const LINE_STATUS_REGISTER: u16 = 5;
pub const MODEM_STATUS_REGISTER: u16 = 6;
pub const SCRATCH_REGISTER: u16 = 7;

pub const DIVISOR_LATCH_LOW: u16 = 0;
pub const DIVISOR_LATCH_HIGH: u16 = 1;

pub const LINE_CONTROL_8_BITS: u8 = 0x03;
pub const LINE_CONTROL_DLAB: u8 = 0x80;

pub const FIFO_ENABLE: u8 = 0x01;
pub const FIFO_CLEAR_RECEIVE: u8 = 0x02;
pub const FIFO_CLEAR_TRANSMIT: u8 = 0x04;
pub const FIFO_TRIGGER_14: u8 = 0xC0;

pub const MODEM_DTR: u8 = 0x01;
pub const MODEM_RTS: u8 = 0x02;
pub const MODEM_OUT1: u8 = 0x04;
pub const MODEM_OUT2: u8 = 0x08;
pub const MODEM_LOOPBACK: u8 = 0x10;

pub const LINE_STATUS_DATA_READY: u8 = 0x01;
pub const LINE_STATUS_TRANSMIT_EMPTY: u8 = 0x20;
