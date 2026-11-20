//! Single Slot AHCI DMA Page Geometry

pub const SECTOR_BYTES = 512;
pub const FIS_OFFSET = 0x400;
pub const TABLE_OFFSET = 0x500;
pub const DATA_OFFSET = 0x800;
pub const PRD_OFFSET = TABLE_OFFSET + 0x80;
pub const HEADER_TABLE_ADDRESS = 8;
pub const PRD_LENGTH_OFFSET = PRD_OFFSET + 12;
pub const HEADER_FLAGS: u32 = 5 | (1 << 16);
pub const REGISTER_FIS: u8 = 0x27;
pub const COMMAND_FRAME: u8 = 0x80;
pub const IDENTIFY: u8 = 0xec;
pub const READ_DMA_EXT: u8 = 0x25;
pub const LBA_MODE: u8 = 0x40;
pub const LBA_LIMIT: u64 = 1 << 48;
pub const DMA_LIMIT: u64 = 1 << 32;
pub const FEATURES_OFFSET = 83 * 2;
pub const CAPACITY_OFFSET = 100 * 2;
pub const GEOMETRY_OFFSET = 106 * 2;
pub const WORD_VALID_MASK: u16 = 0xc000;
pub const WORD_VALID: u16 = 0x4000;
pub const LBA48: u16 = 1 << 10;
pub const LONG_LOGICAL_SECTOR: u16 = 1 << 12;
