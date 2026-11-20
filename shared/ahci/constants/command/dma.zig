//! Single Slot AHCI DMA Page Geometry

pub const SECTOR_BYTES = 512;
pub const FIS_OFFSET = 0x400;
pub const TABLE_OFFSET = 0x500;
pub const DATA_OFFSET = 0x800;
pub const PRD_OFFSET = TABLE_OFFSET + 0x80;
pub const HEADER_TABLE_ADDRESS = 8;
pub const PRD_LENGTH_OFFSET = PRD_OFFSET + 12;
pub const TRANSFERRED_OFFSET = 4;
pub const DMA_LIMIT: u64 = 1 << 32;
pub const HEADER_FLAGS: u32 = 5 | (1 << 16);
