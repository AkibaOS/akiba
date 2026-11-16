//! Loopback Peer Bounds

pub const REQUEST_BYTES: usize = 1024;
pub const TIMEOUT_MS: u32 = 2000;
pub const TIMEOUT_SECONDS: i64 = 2;
pub const SLOW_BYTES: usize = 80;
pub const BYTE_INTERVAL_NS: u64 = 100000000;
pub const MIN_DEADLINE_NS: u64 = 5000000000;
pub const MAX_DEADLINE_NS: u64 = 8000000000;
