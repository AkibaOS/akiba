//! Font Limits

pub const MAX_COMPONENT_DEPTH: u8 = 8;
pub const MAX_COMPONENT_VISITS: usize = 1 << 16;
pub const MAX_EXPANDED_POINTS: usize = 1 << 20;

pub const MIN_UNITS_PER_EM: u16 = 16;
pub const MAX_UNITS_PER_EM: u16 = 16384;

pub const HEAD_SIZE: usize = 54;
pub const MAXP_SIZE: usize = 32;
pub const HHEA_SIZE: usize = 36;

pub const OFFSET_UNITS_PER_EM: usize = 18;
pub const OFFSET_INDEX_TO_LOCATION: usize = 50;
pub const OFFSET_GLYPH_COUNT: usize = 4;
pub const OFFSET_ASCENDER: usize = 4;
pub const OFFSET_LONG_METRIC_COUNT: usize = 34;
