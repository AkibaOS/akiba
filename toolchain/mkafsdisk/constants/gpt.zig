//! GPT Layout Constants

pub const MBR_PARTITION_OFFSET: usize = 0x1BE;
pub const MBR_ENTRY_TYPE_OFFSET: usize = 4;
pub const MBR_ENTRY_FIRST_LBA_OFFSET: usize = 8;
pub const MBR_ENTRY_SECTOR_COUNT_OFFSET: usize = 12;
pub const MBR_SIGNATURE_OFFSET: usize = 510;
pub const MBR_SIGNATURE_LOW: u8 = 0x55;
pub const MBR_SIGNATURE_HIGH: u8 = 0xAA;
pub const MBR_PROTECTIVE_TYPE: u8 = 0xEE;

pub const HEADER_REVISION: u32 = 0x00010000;
pub const HEADER_SIZE: u32 = 92;
pub const HEADER_LBA: u64 = 1;
pub const ENTRIES_START_LBA: u64 = 2;
pub const PARTITION_ENTRY_SIZE: u32 = 128;
pub const PARTITION_ENTRY_COUNT: u32 = 128;
pub const ENTRIES_BYTES: usize = PARTITION_ENTRY_SIZE * PARTITION_ENTRY_COUNT;

pub const HEADER_OFFSET_SIGNATURE: usize = 0;
pub const HEADER_OFFSET_REVISION: usize = 8;
pub const HEADER_OFFSET_HEADER_SIZE: usize = 12;
pub const HEADER_OFFSET_HEADER_CRC: usize = 16;
pub const HEADER_OFFSET_CURRENT_LBA: usize = 24;
pub const HEADER_OFFSET_BACKUP_LBA: usize = 32;
pub const HEADER_OFFSET_FIRST_USABLE: usize = 40;
pub const HEADER_OFFSET_LAST_USABLE: usize = 48;
pub const HEADER_OFFSET_DISK_GUID: usize = 56;
pub const HEADER_OFFSET_ENTRIES_LBA: usize = 72;
pub const HEADER_OFFSET_ENTRY_COUNT: usize = 80;
pub const HEADER_OFFSET_ENTRY_SIZE: usize = 84;
pub const HEADER_OFFSET_ENTRIES_CRC: usize = 88;

pub const ENTRY_OFFSET_TYPE_GUID: usize = 0;
pub const ENTRY_OFFSET_UNIQUE_GUID: usize = 16;
pub const ENTRY_OFFSET_FIRST_LBA: usize = 32;
pub const ENTRY_OFFSET_LAST_LBA: usize = 40;
pub const ENTRY_OFFSET_NAME: usize = 56;

pub const CRC32_POLYNOMIAL: u32 = 0xEDB88320;
pub const CRC32_INITIAL: u32 = 0xFFFFFFFF;

pub const ESP_TYPE_GUID = [16]u8{
    0x28, 0x73, 0x2A, 0xC1,
    0x1F, 0xF8, 0xD2, 0x11,
    0xBA, 0x4B, 0x00, 0xA0,
    0xC9, 0x3E, 0xC9, 0x3B,
};

pub const ESP_UNIQUE_GUID = [16]u8{ 0x01, 0x02, 0x03, 0x04, 0x05, 0x06, 0x07, 0x08, 0x09, 0x0A, 0x0B, 0x0C, 0x0D, 0x0E, 0x0F, 0x10 };
pub const AFS_UNIQUE_GUID = [16]u8{ 0x11, 0x12, 0x13, 0x14, 0x15, 0x16, 0x17, 0x18, 0x19, 0x1A, 0x1B, 0x1C, 0x1D, 0x1E, 0x1F, 0x20 };
pub const DISK_GUID = [16]u8{ 0xAA, 0xBB, 0xCC, 0xDD, 0xEE, 0xFF, 0x00, 0x11, 0x22, 0x33, 0x44, 0x55, 0x66, 0x77, 0x88, 0x99 };
