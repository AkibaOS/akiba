//! Kagami Protection Constants

pub const none: u8 = 0x00;
pub const read: u8 = 0x01;
pub const write: u8 = 0x02;
pub const execute: u8 = 0x04;
pub const user: u8 = 0x08;
pub const wired: u8 = 0x10;
pub const nocache: u8 = 0x20;

pub const kernel_read: u8 = read;
pub const kernel_write: u8 = read | write;
pub const kernel_execute: u8 = read | execute;
pub const kernel_all: u8 = read | write | execute;

pub const user_read: u8 = read | user;
pub const user_write: u8 = read | write | user;
pub const user_execute: u8 = read | execute | user;
pub const user_all: u8 = read | write | execute | user;
