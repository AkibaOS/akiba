//! GDT Flags Constants

pub const granularity_byte: u4 = 0;
pub const granularity_page: u4 = 1 << 3;

pub const size_16bit: u4 = 0;
pub const size_32bit: u4 = 1 << 2;

pub const long_mode_code: u4 = 1 << 1;

pub const kernel_code_flags: u4 = granularity_page | long_mode_code;
pub const kernel_data_flags: u4 = granularity_page | size_32bit;
pub const user_code_flags: u4 = granularity_page | long_mode_code;
pub const user_data_flags: u4 = granularity_page | size_32bit;
pub const tss_flags: u4 = 0;
