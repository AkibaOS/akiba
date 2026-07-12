//! Memory Size Constants

pub const PAGE_SIZE: u64 = 4096;
pub const PAGE_SHIFT: u6 = 12;
pub const PAGE_MASK: u64 = PAGE_SIZE - 1;

pub const LARGE_PAGE_SIZE: u64 = 2 * 1024 * 1024;
pub const LARGE_PAGE_SHIFT: u6 = 21;
pub const LARGE_PAGE_MASK: u64 = LARGE_PAGE_SIZE - 1;

pub const HUGE_PAGE_SIZE: u64 = 1024 * 1024 * 1024;
pub const HUGE_PAGE_SHIFT: u6 = 30;
pub const HUGE_PAGE_MASK: u64 = HUGE_PAGE_SIZE - 1;

pub const KILOBYTE: u64 = 1024;
pub const MEGABYTE: u64 = 1024 * KILOBYTE;
pub const GIGABYTE: u64 = 1024 * MEGABYTE;
pub const TERABYTE: u64 = 1024 * GIGABYTE;

pub const ENTRIES_PER_PAGE_TABLE: u64 = 512;
pub const PAGE_TABLE_LEVELS: u8 = 4;
