//! Memory Size Constants

pub const page_size: u64 = 4096;
pub const page_shift: u6 = 12;
pub const page_mask: u64 = page_size - 1;

pub const large_page_size: u64 = 2 * 1024 * 1024;
pub const large_page_shift: u6 = 21;
pub const large_page_mask: u64 = large_page_size - 1;

pub const huge_page_size: u64 = 1024 * 1024 * 1024;
pub const huge_page_shift: u6 = 30;
pub const huge_page_mask: u64 = huge_page_size - 1;

pub const kilobyte: u64 = 1024;
pub const megabyte: u64 = 1024 * kilobyte;
pub const gigabyte: u64 = 1024 * megabyte;
pub const terabyte: u64 = 1024 * gigabyte;

pub const entries_per_page_table: u64 = 512;
pub const page_table_levels: u8 = 4;
