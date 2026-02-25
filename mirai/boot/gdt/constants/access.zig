//! GDT Access Flag Constants

pub const accessed: u8 = 1 << 0;
pub const read_write: u8 = 1 << 1;
pub const direction_conforming: u8 = 1 << 2;
pub const executable: u8 = 1 << 3;
pub const descriptor_type: u8 = 1 << 4;
pub const dpl_ring_1: u8 = 1 << 5;
pub const dpl_ring_2: u8 = 2 << 5;
pub const dpl_ring_3: u8 = 3 << 5;
pub const present: u8 = 1 << 7;

pub const kernel_code_access: u8 = present | descriptor_type | executable | read_write;
pub const kernel_data_access: u8 = present | descriptor_type | read_write;
pub const user_code_access: u8 = present | dpl_ring_3 | descriptor_type | executable | read_write;
pub const user_data_access: u8 = present | dpl_ring_3 | descriptor_type | read_write;

pub const tss_access: u8 = present | 0x09;
pub const tss_access_busy: u8 = present | 0x0B;
