//! Primary GPT Header Fields

pub const SIGNATURE: u64 = 0x5452415020494645;
pub const MINIMUM_REVISION: u32 = 0x00010000;
pub const MINIMUM_BYTES: usize = 92;
pub const PRIMARY_LBA: u64 = 1;
pub const MINIMUM_TABLE_LBA: u64 = PRIMARY_LBA + 1;

pub const SIGNATURE_OFFSET = 0;
pub const REVISION_OFFSET = 8;
pub const SIZE_OFFSET = 12;
pub const CRC_OFFSET = 16;
pub const RESERVED_OFFSET = 20;
pub const CURRENT_OFFSET = 24;
pub const ALTERNATE_OFFSET = 32;
pub const FIRST_USABLE_OFFSET = 40;
pub const LAST_USABLE_OFFSET = 48;
pub const DISK_GUID_OFFSET = 56;
pub const TABLE_LBA_OFFSET = 72;
pub const ENTRY_COUNT_OFFSET = 80;
pub const ENTRY_BYTES_OFFSET = 84;
pub const TABLE_CRC_OFFSET = 88;
