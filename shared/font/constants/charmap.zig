//! Character Map Constants

pub const PLATFORM_UNICODE: u16 = 0;
pub const PLATFORM_WINDOWS: u16 = 3;

pub const ENCODING_WINDOWS_BMP: u16 = 1;
pub const ENCODING_WINDOWS_FULL: u16 = 10;

pub const FORMAT_SEGMENT_MAPPING: u16 = 4;
pub const FORMAT_SEGMENTED_COVERAGE: u16 = 12;

pub const MISSING_GLYPH: u16 = 0;

pub const ENCODING_RECORD_SIZE: usize = 8;
pub const GROUP_SIZE: usize = 12;
pub const SEGMENT_HEADER_SIZE: usize = 16;
pub const COVERAGE_HEADER_SIZE: usize = 16;
pub const SEGMENT_COUNT_OFFSET: usize = 6;
pub const SEGMENT_ENDS_OFFSET: usize = 14;
pub const COVERAGE_GROUP_COUNT_OFFSET: usize = 12;
pub const BMP_LAST: u16 = 0xFFFF;
pub const UNICODE_LAST: u32 = 0x10FFFF;
pub const GLYPH_DOMAIN_SIZE: u32 = 1 << @bitSizeOf(u16);
