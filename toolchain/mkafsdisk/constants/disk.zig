//! Disk Layout Constants

pub const SECTOR_SIZE: u32 = 512;

pub const ESP_START_SECTOR: u32 = 2048;
pub const ESP_SIZE_SECTORS: u32 = 69632;

pub const GPT_RESERVED_SECTORS: u32 = 34;
pub const GPT_BACKUP_ENTRIES_SECTORS: u32 = 33;

pub const FAT32_MINIMUM_CLUSTERS: u32 = 65525;
