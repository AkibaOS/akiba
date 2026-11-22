//! Independent Secondary AHCI Data Fixture

pub const ADDRESS: u16 = 0x0038;
pub const PORT: u8 = 0;
pub const LOCATION: u64 = @as(u64, ADDRESS) << 8 | PORT;
pub const BLOCK_BYTES = 512;
pub const LAST_LBA: u64 = 8191;
pub const FIRST: u64 = 2048;
pub const LAST: u64 = 4095;
pub const SENTINEL: u8 = 0xa7;
pub const DISK_GUID: [16]u8 = @splat(0x91);
pub const PARTITION_GUID: [16]u8 = @splat(0x37);
pub const CODE: u64 = 0x1600000;
pub const DATA: u64 = 0x1700000;
pub const STACK: u64 = 0x1800000;
pub const OUTPUT: u64 = 2048;
pub const SIGNATURE = [_]u8{ 'E', 'F', 'I', ' ', 'P', 'A', 'R', 'T' };
pub const REVISION = 0x10000;
pub const HEADER_BYTES = 92;
pub const ENTRY_BYTES = 128;
pub const ENTRY_COUNT = 128;
pub const TABLE_LBA = 2;
pub const FIRST_USABLE = 34;
pub const LAST_USABLE = LAST_LBA - 33;
pub const AFS_TYPE = [16]u8{ 0x42, 0x49, 0x4b, 0x41, 0x46, 0x41, 0, 0x53, 0, 0, 0, 0, 0, 0, 0, 1 };
