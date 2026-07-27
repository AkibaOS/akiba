//! GDT Selector Constants

pub const NULL_SELECTOR: u16 = 0x00;
pub const KERNEL_CODE_SELECTOR: u16 = 0x08;
pub const KERNEL_DATA_SELECTOR: u16 = 0x10;
pub const USER_CODE_SELECTOR: u16 = 0x18;
pub const USER_DATA_SELECTOR: u16 = 0x20;
pub const TSS_SELECTOR: u16 = 0x28;

pub const KERNEL_CODE_INDEX: u16 = 1;
pub const KERNEL_DATA_INDEX: u16 = 2;
pub const USER_CODE_INDEX: u16 = 3;
pub const USER_DATA_INDEX: u16 = 4;
pub const TSS_INDEX: u16 = 5;

pub const RING_0: u8 = 0;
pub const RING_3: u8 = 3;
