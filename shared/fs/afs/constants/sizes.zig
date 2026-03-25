//! AFS Size Constants

pub const volume_header_cell: u64 = 0;
pub const volume_header_size: u32 = 512;
pub const alternate_volume_header_offset: u64 = 1024;

pub const default_cell_size: u32 = 4096;
pub const minimum_cell_size: u32 = 512;
pub const maximum_cell_size: u32 = 65536;

pub const max_identity_length: usize = 1024;
pub const span_inline_count: usize = 8;

pub const attribute_inline_data_max: u32 = 3802;

pub const journal_header_size: u32 = 512;
pub const journal_info_cell: u64 = 2;
