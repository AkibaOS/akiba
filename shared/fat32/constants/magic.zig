//! FAT32 Signatures

pub const BOOT_SIGNATURE: u16 = 0xAA55;

pub const FS_TYPE_FAT32: [8]u8 = .{ 'F', 'A', 'T', '3', '2', ' ', ' ', ' ' };

pub const FSINFO_SIGNATURE_1: u32 = 0x41615252;
pub const FSINFO_SIGNATURE_2: u32 = 0x61417272;
pub const FSINFO_SIGNATURE_3: u32 = 0xAA550000;
pub const FSINFO_UNKNOWN: u32 = 0xFFFFFFFF;
