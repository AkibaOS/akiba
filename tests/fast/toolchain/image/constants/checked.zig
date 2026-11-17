//! Checked Shared AFS Construction Expectations

pub const ALLOCATION_REQUEST_CELLS: u32 = 2;
pub const BITMAP_BYTES: usize = 3;
pub const OCCUPIED_CURSOR_BITMAP = [_]u8{ 0x0f, 0x00, 0xf8 };
pub const OCCUPIED_INTERIOR_BITMAP = [_]u8{ 0x17, 0x00, 0xf8 };
pub const OCCUPIED_FREE_CELLS: u32 = 15;
pub const FIRST_DATA_CELL: u32 = 3;
pub const GUARD_BYTE: u8 = 0xa5;
pub const GUARD_BYTES: usize = 16;
pub const INVALID_CURSOR: u32 = 20;
pub const INVALID_RANGE_START: u32 = 17;
pub const INVALID_RANGE_COUNT: u32 = 3;
pub const LAST_BYTE_MASKS = [_]u8{ 0x40, 0x80, 0x01 };
pub const MAXIMUM_CHANNEL_BYTES: u64 = 17592186040320;
pub const SHORT_BITMAP_BYTES: usize = 2;
pub const TOTAL_CELLS: u32 = 19;
pub const INITIAL_BITMAP = [_]u8{ 0x07, 0x00, 0xf8 };
