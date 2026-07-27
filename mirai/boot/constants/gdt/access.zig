//! GDT Access Flag Constants

pub const ACCESSED: u8 = 1 << 0;
pub const READ_WRITE: u8 = 1 << 1;
pub const DIRECTION_CONFORMING: u8 = 1 << 2;
pub const EXECUTABLE: u8 = 1 << 3;
pub const DESCRIPTOR_TYPE: u8 = 1 << 4;
pub const DPL_RING_1: u8 = 1 << 5;
pub const DPL_RING_2: u8 = 2 << 5;
pub const DPL_RING_3: u8 = 3 << 5;
pub const PRESENT: u8 = 1 << 7;

pub const DPL_SHIFT: u3 = 5;
pub const DPL_MASK: u8 = 0x03;

pub const KERNEL_CODE_ACCESS: u8 = PRESENT | DESCRIPTOR_TYPE | EXECUTABLE | READ_WRITE;
pub const KERNEL_DATA_ACCESS: u8 = PRESENT | DESCRIPTOR_TYPE | READ_WRITE;
pub const USER_CODE_ACCESS: u8 = PRESENT | DPL_RING_3 | DESCRIPTOR_TYPE | EXECUTABLE | READ_WRITE;
pub const USER_DATA_ACCESS: u8 = PRESENT | DPL_RING_3 | DESCRIPTOR_TYPE | READ_WRITE;

pub const TSS_TYPE_AVAILABLE: u8 = 0x09;
pub const TSS_TYPE_BUSY: u8 = 0x0B;
pub const TSS_ACCESS: u8 = PRESENT | TSS_TYPE_AVAILABLE;
pub const TSS_ACCESS_BUSY: u8 = PRESENT | TSS_TYPE_BUSY;
