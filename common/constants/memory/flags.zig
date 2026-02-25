//! Memory Flag Constants

pub const protection_read: u8 = 0x01;
pub const protection_write: u8 = 0x02;
pub const protection_execute: u8 = 0x04;
pub const protection_user: u8 = 0x08;

pub const protection_kernel_read_only: u8 = protection_read;
pub const protection_kernel_read_write: u8 = protection_read | protection_write;
pub const protection_kernel_execute: u8 = protection_read | protection_execute;
pub const protection_user_read_only: u8 = protection_read | protection_user;
pub const protection_user_read_write: u8 = protection_read | protection_write | protection_user;
pub const protection_user_execute: u8 = protection_read | protection_execute | protection_user;

pub const allocation_wired: u32 = 0x00000001;
pub const allocation_contiguous: u32 = 0x00000002;
pub const allocation_zero_fill: u32 = 0x00000004;
pub const allocation_no_cache: u32 = 0x00000008;
pub const allocation_write_combine: u32 = 0x00000010;

pub const region_anonymous: u32 = 0x00000001;
pub const region_shared: u32 = 0x00000002;
pub const region_copy_on_write: u32 = 0x00000004;
pub const region_stack: u32 = 0x00000008;
pub const region_guard: u32 = 0x00000010;
