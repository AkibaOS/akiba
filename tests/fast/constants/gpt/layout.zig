//! Independent Native GPT Test Geometry

pub const BLOCK_BYTES = 512;
pub const HEADER_BYTES = 92;
pub const ENTRY_BYTES = 160;
pub const ENTRY_COUNT = 3;
pub const TABLE_BYTES = ENTRY_BYTES * ENTRY_COUNT;
pub const STREAM_ENTRY_COUNT = 4;
pub const STREAM_TABLE_BYTES = ENTRY_BYTES * STREAM_ENTRY_COUNT;
pub const STREAM_SECTORS = (STREAM_TABLE_BYTES - 1) / BLOCK_BYTES + 1;
pub const STREAM_READS = STREAM_SECTORS + 1;
pub const ENTRY_PREFIX_BYTES = 48;
pub const HEADER_TABLE_OFFSET = 72;
pub const HEADER_COUNT_OFFSET = 80;
pub const PRIMARY_LBA = 1;
pub const TABLE_LBA = 2;
pub const FIRST_USABLE = 8;
pub const LAST_USABLE = 58;
pub const DISK_LAST_LBA = 63;
pub const VOLUME_FIRST = 12;
pub const VOLUME_LAST = 32;
pub const DISK_GUID: [16]u8 = @splat(0x6d);
pub const PARTITION_GUID: [16]u8 = @splat(0x42);
pub const AFS_TYPE = [16]u8{ 0x42, 0x49, 0x4b, 0x41, 0x46, 0x41, 0, 0x53, 0, 0, 0, 0, 0, 0, 0, 1 };
