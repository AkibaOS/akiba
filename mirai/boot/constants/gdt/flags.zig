//! GDT Flags Constants

pub const GRANULARITY_BYTE: u4 = 0;
pub const GRANULARITY_PAGE: u4 = 1 << 3;

pub const SIZE_16BIT: u4 = 0;
pub const SIZE_32BIT: u4 = 1 << 2;

pub const LONG_MODE_CODE: u4 = 1 << 1;

pub const KERNEL_CODE_FLAGS: u4 = GRANULARITY_PAGE | LONG_MODE_CODE;
pub const KERNEL_DATA_FLAGS: u4 = GRANULARITY_PAGE | SIZE_32BIT;
pub const USER_CODE_FLAGS: u4 = GRANULARITY_PAGE | LONG_MODE_CODE;
pub const USER_DATA_FLAGS: u4 = GRANULARITY_PAGE | SIZE_32BIT;
pub const TSS_FLAGS: u4 = 0;

pub const SEGMENT_LIMIT: u20 = 0xFFFFF;
