//! Driver Service Postman Wire Limits And Letters

pub const MAX_PAYLOAD_BYTES: usize = 4096;
pub const SERVICE_QUERY: u64 = 0x50554c530004;
pub const SERVICE_READY: u64 = 0x50554c530005;
pub const SERVICE_STOP: u64 = 0x50554c530006;
pub const SERVICE_STOPPED: u64 = 0x50554c530007;
pub const REFUSED: u64 = 0x50554c530008;
