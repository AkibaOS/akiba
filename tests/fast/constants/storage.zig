//! Storage Regression Fixtures

pub const CELL_SIZE: u32 = 512;
pub const TOTAL_CELLS: u64 = 8;
pub const DEVICE_BYTES: usize = CELL_SIZE * TOTAL_CELLS;
pub const TRANSFER_CAPACITY: usize = 32;
pub const CELL_VALUES = [_]u8{ 0x11, 0x22, 0x33, 0x44, 0x55, 0x66, 0x77, 0x88 };
pub const GUARD_BYTE: u8 = 0xa5;
pub const SCRATCH_BYTE: u8 = 0xcc;
pub const GUARD_BYTES: usize = 4;
pub const PARTIAL_BYTES: usize = 7;

pub const TREE_BYTES: usize = 1024;
pub const NODE_KIND_OFFSET: usize = 8;
pub const NODE_COUNT_OFFSET: usize = 10;
pub const FIRST_KEY_OFFSET: usize = 16;
pub const SECOND_KEY_OFFSET: usize = 122;
pub const FIRST_PAYLOAD_OFFSET: usize = 26;
pub const LEAF_TABLE_OFFSET: usize = 1018;
pub const THREAD_PAYLOAD_OFFSET: usize = 24;
pub const THREAD_LENGTH_OFFSET: usize = 32;
pub const FIRST_INDEX_CHILD: u32 = 0x11223344;
pub const SECOND_INDEX_CHILD: u32 = 0x55667788;

pub const LEAF_DESCRIPTOR = [_]u8{ 0, 0, 0, 0, 0, 0, 0, 0, 0xff, 1, 3, 0, 0, 0, 0, 0 };
pub const INDEX_DESCRIPTOR = [_]u8{ 0, 0, 0, 0, 0, 0, 0, 0, 0, 2, 2, 0, 0, 0, 0, 0 };
pub const THREAD_DESCRIPTOR = [_]u8{ 0, 0, 0, 0, 0, 0, 0, 0, 0xff, 1, 1, 0, 0, 0, 0, 0 };
pub const STACK_KEY = [_]u8{ 10, 0, 0, 0, 7, 0, 0, 0, 'A', 0 };
pub const UNIT_KEY = [_]u8{ 10, 0, 0, 0, 7, 0, 0, 0, 'B', 0 };
pub const THREAD_KEY = [_]u8{ 8, 0, 0, 0, 34, 0, 0, 0 };
pub const STACK_RECORD = [_]u8{ 1, 0, 2, 0, 0, 0, 0, 0, 33, 0, 0, 0 } ++ [_]u8{0} ** 84;
pub const UNIT_RECORD = [_]u8{ 2, 0, 2, 0, 0, 0, 0, 0, 34, 0, 0, 0 } ++ [_]u8{0} ** 388;
pub const THREAD_RECORD = [_]u8{ 4, 0, 0, 0, 7, 0, 0, 0, 2, 0, 0x2c, 0x67, 'B', 0 };
pub const TREE_LEAF = LEAF_DESCRIPTOR ++ STACK_KEY ++ STACK_RECORD ++ UNIT_KEY ++ UNIT_RECORD ++ THREAD_KEY ++ THREAD_RECORD ++ [_]u8{0} ** 464 ++ [_]u8{ 0x14, 0x02, 0x7a, 0, 0x10, 0 };
pub const TREE_INDEX = INDEX_DESCRIPTOR ++ STACK_KEY ++ [_]u8{ 0x44, 0x33, 0x22, 0x11 } ++ [_]u8{ 10, 0, 0, 0, 7, 0, 0, 0, 'C', 0 } ++ [_]u8{ 0x88, 0x77, 0x66, 0x55 } ++ [_]u8{0} ** 16 ++ [_]u8{ 30, 0, 16, 0 };
pub const TREE_THREAD = THREAD_DESCRIPTOR ++ THREAD_KEY ++ THREAD_RECORD ++ [_]u8{ 16, 0 };
pub const TREE_SHORT_THREAD = THREAD_DESCRIPTOR ++ THREAD_KEY ++ [_]u8{ 3, 0, 0, 0, 7, 0, 0, 0 } ++ [_]u8{ 16, 0 };

pub const BOOT_MAGIC: u64 = 0x494152494d424b41;
pub const BOOT_VERSION: u32 = 5;
pub const FAT_SECTOR_BYTES: usize = 512;
pub const FAT_SIGNATURE_OFFSET: usize = 510;
pub const FAT_VOLUME_OFFSET: usize = 67;
pub const FSINFO_SECOND_SIGNATURE_OFFSET: usize = 484;
pub const FSINFO_HINTS_OFFSET: usize = 488;
pub const FSINFO_TRAILER_OFFSET: usize = 508;
