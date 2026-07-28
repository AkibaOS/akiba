//! Font Limits

pub const MAX_POINTS: usize = 1024;
pub const MAX_CONTOURS: usize = 128;
pub const MAX_COMPONENT_DEPTH: u8 = 8;

pub const HEAD_SIZE: usize = 54;
pub const MAXP_SIZE: usize = 32;
pub const HHEA_SIZE: usize = 36;

pub const OFFSET_UNITS_PER_EM: usize = 18;
pub const OFFSET_INDEX_TO_LOCATION: usize = 50;
pub const OFFSET_GLYPH_COUNT: usize = 4;
pub const OFFSET_MAX_POINTS: usize = 6;
pub const OFFSET_MAX_CONTOURS: usize = 8;
pub const OFFSET_MAX_COMPOSITE_POINTS: usize = 10;
pub const OFFSET_ASCENDER: usize = 4;
pub const OFFSET_LONG_METRIC_COUNT: usize = 34;
