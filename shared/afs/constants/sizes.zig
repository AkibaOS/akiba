//! AFS Size Constants

pub const VOLUME_HEADER_CELL: u64 = 0;
pub const VOLUME_HEADER_SIZE: u32 = 512;
pub const ALTERNATE_VOLUME_HEADER_OFFSET: u64 = 1024;

pub const DEFAULT_CELL_SIZE: u32 = 4096;
pub const MINIMUM_CELL_SIZE: u32 = 512;
pub const MAXIMUM_CELL_SIZE: u32 = 65536;

pub const MAX_IDENTITY_LENGTH: usize = 1024;
pub const SPAN_INLINE_COUNT: usize = 8;

pub const ATTRIBUTE_INLINE_DATA_MAX: u32 = 3802;

pub const JOURNAL_HEADER_SIZE: u32 = 512;
pub const JOURNAL_INFO_CELL: u64 = 2;
