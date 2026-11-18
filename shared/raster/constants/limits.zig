//! Raster Limits

pub const PIXEL_BITS: u5 = 6;
pub const ONE_PIXEL: i32 = 1 << PIXEL_BITS;
pub const PIXEL_MASK: i32 = ONE_PIXEL - 1;

pub const COVERAGE_SHIFT: u5 = PIXEL_BITS * 2 + 1 - 8;
pub const COVERAGE_FULL: i32 = 255;

pub const TILE_COLUMNS: usize = 128;
pub const MAX_SUBDIVISION_DEPTH: u8 = 16;
pub const MAX_FLATTEN_STEPS: usize = 1 << 24;

pub const FLATNESS_TOLERANCE: i32 = ONE_PIXEL / 4;
