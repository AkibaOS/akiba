//! Raster Limits

pub const PIXEL_BITS: u5 = 6;
pub const ONE_PIXEL: i32 = 1 << PIXEL_BITS;
pub const PIXEL_MASK: i32 = ONE_PIXEL - 1;

pub const COVERAGE_SHIFT: u5 = PIXEL_BITS * 2 + 1 - 8;
pub const COVERAGE_FULL: i32 = 255;

pub const MAX_EDGES: usize = 4096;
pub const MAX_ROW_WIDTH: usize = 640;
pub const MAX_SUBDIVISION_DEPTH: u8 = 16;

pub const FLATNESS_TOLERANCE: i32 = ONE_PIXEL / 4;
