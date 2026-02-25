//! Serial Register Constants

pub const data_register: u16 = 0;
pub const interrupt_enable_register: u16 = 1;
pub const fifo_control_register: u16 = 2;
pub const line_control_register: u16 = 3;
pub const modem_control_register: u16 = 4;
pub const line_status_register: u16 = 5;
pub const modem_status_register: u16 = 6;
pub const scratch_register: u16 = 7;

pub const divisor_latch_low: u16 = 0;
pub const divisor_latch_high: u16 = 1;

pub const line_control_8_bits: u8 = 0x03;
pub const line_control_dlab: u8 = 0x80;

pub const fifo_enable: u8 = 0x01;
pub const fifo_clear_receive: u8 = 0x02;
pub const fifo_clear_transmit: u8 = 0x04;
pub const fifo_trigger_14: u8 = 0xC0;

pub const modem_dtr: u8 = 0x01;
pub const modem_rts: u8 = 0x02;
pub const modem_out1: u8 = 0x04;
pub const modem_out2: u8 = 0x08;
pub const modem_loopback: u8 = 0x10;

pub const line_status_data_ready: u8 = 0x01;
pub const line_status_transmit_empty: u8 = 0x20;
