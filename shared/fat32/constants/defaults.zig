//! FAT32 Creation Defaults

pub const DEFAULT_OEM_NAME: [8]u8 = .{ 'M', 'S', 'W', 'I', 'N', '4', '.', '1' };
pub const DEFAULT_MEDIA_TYPE: u8 = 0xF8;
pub const DEFAULT_DRIVE_NUMBER: u8 = 0x80;
pub const DEFAULT_EXTENDED_BOOT_SIGNATURE: u8 = 0x29;

pub const DEFAULT_JUMP_BOOT: [3]u8 = .{ 0xEB, 0x58, 0x90 };
pub const DEFAULT_SECTORS_PER_CLUSTER: u8 = 1;
pub const DEFAULT_RESERVED_SECTORS: u16 = 32;
pub const DEFAULT_FAT_COUNT: u8 = 2;
pub const DEFAULT_SECTORS_PER_TRACK: u16 = 63;
pub const DEFAULT_HEAD_COUNT: u16 = 255;
pub const DEFAULT_FSINFO_SECTOR: u16 = 1;
pub const DEFAULT_BACKUP_BOOT_SECTOR: u16 = 6;
pub const DEFAULT_VOLUME_ID: u32 = 0x12345678;
pub const DEFAULT_VOLUME_LABEL: [11]u8 = .{ 'F', 'A', 'T', '3', '2', ' ', 'D', 'I', 'S', 'K', ' ' };
