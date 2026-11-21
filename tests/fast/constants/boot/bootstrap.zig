//! Independent Embedded ELF Segment Fixture Values

pub const ADDRESS: u64 = 0x60000000;
pub const READ_ONLY: u32 = 4;
pub const READ_WRITE: u32 = 6;
pub const FLAGS_OFFSET = 4;
pub const UNIT_OFFSET = 8;
pub const VIRTUAL_OFFSET = 16;
pub const UNIT_BYTES_OFFSET = 32;
pub const MEMORY_BYTES_OFFSET = 40;
pub const PAYLOAD_INDEX = 1;
pub const DUPLICATE_INDEX = 2;
pub const PAYLOAD_BYTES = 32;
