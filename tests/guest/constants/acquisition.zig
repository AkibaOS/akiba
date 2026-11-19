//! Hikari Disk Acquisition Fixtures

const base = @import("hikari").efi.types.base;

pub const BLOCK_BYTES: usize = 512;
pub const DISK_BLOCKS: usize = 128;
pub const DISK_BYTES: usize = BLOCK_BYTES * DISK_BLOCKS;
pub const IO_ALIGNMENT: u32 = 64;
pub const MEDIA_ID: u32 = 7;
pub const POOL_SLOTS: usize = 4;
pub const POOL_BYTES: usize = 32768;
pub const LARGE_ENTRY_COUNT: u32 = 129;
pub const LARGE_BLOCK_BYTES: u32 = 8192;
pub const FAT_MISMATCH_BYTES: u16 = 4096;
pub const POOL_OFFSET: usize = 8;
pub const POOL_GUARD: u8 = 0xD7;
pub const MAX_CALLS: usize = 16;
pub const HEADER_LBA: u64 = 1;
pub const HEADER_BYTES: usize = 92;
pub const TABLE_LBA: u64 = 2;
pub const ENTRY_BYTES: usize = 160;
pub const ENTRY_COUNT: u32 = 4;
pub const TABLE_BYTES: usize = ENTRY_BYTES * ENTRY_COUNT;
pub const TABLE_READ_BYTES: usize = 1024;
pub const TABLE_PADDING: u8 = 0xB6;
pub const FIRST_USABLE_LBA: u64 = 8;
pub const LAST_USABLE_LBA: u64 = 62;
pub const PARTITION_FIRST_LBA: u64 = 24;
pub const PARTITION_LAST_LBA: u64 = 55;
pub const VOLUME_CELLS: u32 = 32;
pub const PAYLOAD_CELL: u64 = 3;
pub const UNIT_LIMIT: u64 = 64;
pub const UNIT_PAYLOAD = [_]u8{ 0x31, 0x00, 0xFE, 0x7F, 0x80, 0x55, 0xAA, 0x42 };
pub const TYPE_A: base.GUID = .{
    .TimeLow = 0x12345678,
    .TimeMid = 0x1357,
    .TimeHighAndVersion = 0x2468,
    .ClockSequenceAndNode = .{ 0x80, 1, 2, 3, 4, 5, 6, 7 },
};
pub const TYPE_B: base.GUID = .{
    .TimeLow = 0x414B4942,
    .TimeMid = 0x4146,
    .TimeHighAndVersion = 0x5300,
    .ClockSequenceAndNode = .{ 0, 0, 0, 0, 0, 0, 0, 1 },
};
pub const DISK_GUID: base.GUID = .{
    .TimeLow = 0xAABBCCDD,
    .TimeMid = 0xEEFF,
    .TimeHighAndVersion = 0x1020,
    .ClockSequenceAndNode = .{ 0x80, 0x30, 0x40, 0x50, 0x60, 0x70, 0x80, 0x90 },
};
