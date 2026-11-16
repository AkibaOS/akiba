//! Disk Image Integration Fixtures

pub const IMAGE_MEGABYTES: u32 = 64;
pub const IMAGE_BYTES: u64 = 64 * 1024 * 1024;
pub const SECTOR_BYTES: usize = 512;
pub const TOTAL_SECTORS: u64 = 131072;
pub const ESP_FIRST_LBA: u64 = 2048;
pub const ESP_LAST_LBA: u64 = 71679;
pub const ESP_SECTORS: u32 = 69632;
pub const AFS_FIRST_LBA: u64 = 71680;
pub const AFS_LAST_LBA: u64 = 131038;
pub const FIRST_USABLE_LBA: u64 = 34;
pub const BACKUP_HEADER_LBA: u64 = 131071;
pub const BACKUP_TABLE_LBA: u64 = 131039;
pub const PRIMARY_TABLE_LBA: u64 = 2;
pub const FAT_SECTORS: u32 = 536;
pub const FAT_BYTES: usize = FAT_SECTORS * SECTOR_BYTES;
pub const CELL_BYTES: u32 = 4096;
pub const AFS_TOTAL_CELLS: u32 = 7419;
pub const AFS_DATA_START: u32 = 22;
pub const AFS_USED_CELLS: u32 = 27;
pub const UNIT_COUNT: u32 = 5;
pub const STACK_COUNT: u32 = 4;
pub const NEXT_NODE_ID: u32 = 24;
pub const GUARD_BYTES: usize = 16;
pub const GUARD_BYTE: u8 = 0xD7;

pub const MBR_ENTRY: usize = 446;
pub const MBR_ENTRY_BYTES: usize = 16;
pub const MBR_SIGNATURE: usize = 510;
pub const GPT_HEADER_BYTES: usize = 92;
pub const GPT_ENTRY_BYTES: usize = 128;
pub const GPT_ENTRY_COUNT: u32 = 128;
pub const GPT_TABLE_BYTES: usize = GPT_ENTRY_BYTES * GPT_ENTRY_COUNT;
pub const HEADER_REVISION: usize = 8;
pub const HEADER_SIZE: usize = 12;
pub const HEADER_CRC: usize = 16;
pub const HEADER_RESERVED: usize = 20;
pub const HEADER_CURRENT: usize = 24;
pub const HEADER_BACKUP: usize = 32;
pub const HEADER_FIRST_USABLE: usize = 40;
pub const HEADER_LAST_USABLE: usize = 48;
pub const HEADER_DISK_GUID: usize = 56;
pub const HEADER_ENTRIES: usize = 72;
pub const HEADER_COUNT: usize = 80;
pub const HEADER_ENTRY_SIZE: usize = 84;
pub const HEADER_TABLE_CRC: usize = 88;
pub const ENTRY_UNIQUE_GUID: usize = 16;
pub const ENTRY_FIRST: usize = 32;
pub const ENTRY_LAST: usize = 40;
pub const ENTRY_ATTRIBUTES: usize = 48;
pub const ENTRY_NAME: usize = 56;
pub const GUID_BYTES: usize = 16;
pub const ESP_TYPE_GUID = [_]u8{
    0x28, 0x73, 0x2A, 0xC1, 0x1F, 0xF8, 0xD2, 0x11,
    0xBA, 0x4B, 0x00, 0xA0, 0xC9, 0x3E, 0xC9, 0x3B,
};
pub const AFS_TYPE_GUID = [_]u8{
    0x42, 0x49, 0x4B, 0x41, 0x46, 0x41, 0x00, 0x53,
    0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x01,
};
pub const BOOTLOADER_BYTES = ([_]u8{ 0x4D, 0x5A, 0x00, 0xFF } ** 192) ++ [_]u8{0x7E};
pub const CROSS_BYTES = ([_]u8{ 0x31, 0xC7, 0x00, 0xFF } ** 1024) ++ [_]u8{
    0x80, 0x01, 0x02, 0x03, 0x04, 0x05, 0x06, 0x07, 0x08,
    0x09, 0x0A, 0x0B, 0x0C, 0x0D, 0x0E, 0x0F, 0xFE,
};
