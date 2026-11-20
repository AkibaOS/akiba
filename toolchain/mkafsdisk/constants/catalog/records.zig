//! Bulk AFS Catalog Planning Constants

pub const HEADER_RECORD_BYTES: usize = 112;
pub const HEADER_RECORD_COUNT: u16 = 1;
pub const KEY_PARENT_OFFSET: usize = 4;
pub const STACK_RECORD_BYTES: usize = 96;
pub const UNIT_RECORD_BYTES: usize = 400;
pub const IDENTITY_TERMINATOR: u8 = 0;
pub const MAXIMUM_IDENTITY_BYTES: usize = 256;
pub const MAXIMUM_KEY_BYTES: u16 = 520;
pub const MEBIBYTE_BYTES: u64 = 1024 * 1024;
pub const MINIMUM_TREE_NODES: u32 = 2;
pub const NODE_DESCRIPTOR_BYTES: usize = 16;
pub const STACK_MODE: u16 = 0o755;
pub const UNIT_MODE: u16 = 0o644;
