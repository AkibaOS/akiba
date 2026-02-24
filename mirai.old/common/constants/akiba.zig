//! Akiba executable format constants

pub const MAGIC = [8]u8{ 'A', 'K', 'I', 'B', 'A', 'E', 'L', 'F' };
pub const VERSION: u32 = 1;

pub const TYPE_CLI: u32 = 0;
pub const TYPE_GUI: u32 = 1;
pub const TYPE_SERVICE: u32 = 2;
pub const TYPE_LIBRARY: u32 = 3;
