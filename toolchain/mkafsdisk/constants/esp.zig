//! ESP Layout Constants

pub const SECTORS_PER_CLUSTER: u32 = 1;
pub const RESERVED_SECTORS: u32 = 32;
pub const FAT_COUNT: u32 = 2;
pub const VOLUME_ID: u32 = 0x12345678;
pub const FSINFO_SECTOR: u32 = 1;
pub const BACKUP_BOOT_SECTOR: u32 = 6;

pub const DIRECTORY_ENTRY_SIZE: usize = 32;
pub const FIRST_DATA_CLUSTER: u32 = 2;
pub const FIRST_FREE_CLUSTER: u32 = 3;
