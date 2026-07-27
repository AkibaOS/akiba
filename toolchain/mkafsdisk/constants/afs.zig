//! AFS Layout Constants

pub const ALLOCATION_MAP_START_CELL: u32 = 11;
pub const ALLOCATION_MAP_CELLS: u32 = 4;
pub const INDEX_CELLS: u32 = 16;
pub const JOURNAL_START_CELL: u32 = 3;
pub const JOURNAL_CELLS: u32 = 8;

pub const INDEX_HEADER_RECORD_COUNT: u16 = 3;
pub const INDEX_RESERVED_NODES: u32 = 2;
pub const MAX_KEY_LENGTH: u16 = 518;
pub const KEY_COMPARE_TYPE: u8 = 0xCF;
pub const JOURNAL_INITIAL_SEQUENCE: u64 = 1;
