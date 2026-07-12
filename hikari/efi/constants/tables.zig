//! Hikari EFI Table Signature Constants

pub const SYSTEM_TABLE_SIGNATURE: u64 = 0x5453595320494249;
pub const BOOT_SERVICES_SIGNATURE: u64 = 0x56524553544f4f42;
pub const RUNTIME_SERVICES_SIGNATURE: u64 = 0x56524553544e5552;

pub const SYSTEM_TABLE_REVISION_2_100: u32 = (2 << @bitSizeOf(u16)) | 100;
pub const SYSTEM_TABLE_REVISION_2_90: u32 = (2 << @bitSizeOf(u16)) | 90;
pub const SYSTEM_TABLE_REVISION_2_80: u32 = (2 << @bitSizeOf(u16)) | 80;
pub const SYSTEM_TABLE_REVISION_2_70: u32 = (2 << @bitSizeOf(u16)) | 70;
pub const SYSTEM_TABLE_REVISION_2_60: u32 = (2 << @bitSizeOf(u16)) | 60;
pub const SYSTEM_TABLE_REVISION_2_50: u32 = (2 << @bitSizeOf(u16)) | 50;
pub const SYSTEM_TABLE_REVISION_2_40: u32 = (2 << @bitSizeOf(u16)) | 40;
pub const SYSTEM_TABLE_REVISION_2_31: u32 = (2 << @bitSizeOf(u16)) | 31;
pub const SYSTEM_TABLE_REVISION_2_30: u32 = (2 << @bitSizeOf(u16)) | 30;
pub const SYSTEM_TABLE_REVISION_2_20: u32 = (2 << @bitSizeOf(u16)) | 20;
pub const SYSTEM_TABLE_REVISION_2_10: u32 = (2 << @bitSizeOf(u16)) | 10;
pub const SYSTEM_TABLE_REVISION_2_00: u32 = (2 << @bitSizeOf(u16)) | 0;
pub const SYSTEM_TABLE_REVISION_1_10: u32 = (1 << @bitSizeOf(u16)) | 10;
pub const SYSTEM_TABLE_REVISION_1_02: u32 = (1 << @bitSizeOf(u16)) | 2;

pub const SPECIFICATION_MAJOR_REVISION: u32 = 2;
pub const SPECIFICATION_MINOR_REVISION: u32 = 100;
