//! AHCI limits

pub const MAX_PORTS: u8 = 32;
pub const MAX_CMD_SLOTS: u8 = 32;
pub const TIMEOUT_SPIN: u32 = 500000;
pub const TIMEOUT_CMD: u32 = 1000000;
pub const TIMEOUT_WAIT: u32 = 10000000;
pub const CMD_TABLE_CLEAR_SIZE: usize = 256;
pub const PAGE_SIZE: usize = 4096;
