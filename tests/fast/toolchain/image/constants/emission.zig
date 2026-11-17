//! Independent Active AFS Writer Expectations

pub const MODERATE_UNITS: usize = 20;
pub const MODERATE_NAME_BYTES: usize = 32;
pub const MODERATE_STACKS: u32 = 4;
pub const MODERATE_TOTAL_UNITS: u32 = 21;
pub const MODERATE_RECORDS: u32 = 25;
pub const MODERATE_NODES: u32 = 5;
pub const MODERATE_DEPTH: u16 = 2;
pub const MODERATE_DATA_START: usize = 8;
pub const MODERATE_USED_CELLS: usize = 29;
pub const PAYLOAD_BYTES: usize = 8;
pub const PAYLOAD_INDEX_BYTES: usize = 4;
pub const PAYLOAD_SUFFIX = [_]u8{ 0xff, 0x31, 0x00, 0x7e };
pub const SMALL_MIB: u32 = 36;
pub const OVERSIZED_PAYLOAD_CELLS: u64 = 300;
pub const BITMAP_IMAGE_MIB: u32 = 548;
pub const BITMAP_TOTAL_CELLS: u32 = 131323;
pub const BITMAP_CELLS: usize = 5;
pub const BITMAP_BYTES: usize = 16416;
pub const BITMAP_INDEX_START: u64 = 7;
pub const BITMAP_DATA_START: usize = 9;
pub const BITMAP_USED_CELLS: usize = 10;
pub const BITMAP_LAST_BYTE: u8 = 0xf8;
pub const FORMER_UNCOVERED_CELL: u32 = 131072;
pub const PADDING_BYTE: u8 = 0xff;
