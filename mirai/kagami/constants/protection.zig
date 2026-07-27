//! Kagami Protection Constants

pub const NONE: u8 = 0x00;
pub const READ: u8 = 0x01;
pub const WRITE: u8 = 0x02;
pub const EXECUTE: u8 = 0x04;
pub const USER: u8 = 0x08;
pub const WIRED: u8 = 0x10;
pub const NOCACHE: u8 = 0x20;

pub const KERNEL_READ: u8 = READ;
pub const KERNEL_WRITE: u8 = READ | WRITE;
pub const KERNEL_EXECUTE: u8 = READ | EXECUTE;
pub const KERNEL_ALL: u8 = READ | WRITE | EXECUTE;

pub const USER_READ: u8 = READ | USER;
pub const USER_WRITE: u8 = READ | WRITE | USER;
pub const USER_EXECUTE: u8 = READ | EXECUTE | USER;
pub const USER_ALL: u8 = READ | WRITE | EXECUTE | USER;
