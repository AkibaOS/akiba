//! ATA constants

// Commands
pub const CMD_READ_SECTORS: u8 = 0x20;
pub const CMD_WRITE_SECTORS: u8 = 0x30;
pub const CMD_READ_DMA_EX: u8 = 0x25;
pub const CMD_WRITE_DMA_EX: u8 = 0x35;
pub const CMD_IDENTIFY: u8 = 0xEC;

// Status register bits
pub const STATUS_ERR: u8 = 0x01;
pub const STATUS_DRQ: u8 = 0x08;
pub const STATUS_SRV: u8 = 0x10;
pub const STATUS_DF: u8 = 0x20;
pub const STATUS_RDY: u8 = 0x40;
pub const STATUS_BSY: u8 = 0x80;

// Device signatures
pub const SIG_ATA: u32 = 0x00000101;
pub const SIG_ATAPI: u32 = 0xEB140101;
pub const SIG_SEMB: u32 = 0xC33C0101;
pub const SIG_PM: u32 = 0x96690101;

// Port registers (primary)
pub const PRIMARY_DATA: u16 = 0x1F0;
pub const PRIMARY_ERROR: u16 = 0x1F1;
pub const PRIMARY_SECTOR_COUNT: u16 = 0x1F2;
pub const PRIMARY_LBA_LOW: u16 = 0x1F3;
pub const PRIMARY_LBA_MID: u16 = 0x1F4;
pub const PRIMARY_LBA_HIGH: u16 = 0x1F5;
pub const PRIMARY_DRIVE_SELECT: u16 = 0x1F6;
pub const PRIMARY_STATUS: u16 = 0x1F7;
pub const PRIMARY_COMMAND: u16 = 0x1F7;
