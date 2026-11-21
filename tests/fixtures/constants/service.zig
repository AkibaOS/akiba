//! Independent Native Supervisor Probe Protocol

pub const JOBS: u64 = 6;
pub const STEPS: usize = 13;
pub const TIMEOUT_TICKS: u64 = 1000;
pub const STOP_STEPS: u64 = 3;
pub const RECOVERY_TICKS: u64 = (STOP_STEPS + 2 * 2) * TIMEOUT_TICKS;
pub const SHUTDOWN_TICKS: u64 = 6 * STOP_STEPS * TIMEOUT_TICKS;
pub const REPORT: u64 = 0x50554c530001;
pub const SNAPSHOT: u64 = 0x50554c530002;
pub const READY_STAGE: u64 = 2;
pub const FAILED_STAGE: u64 = 3;
pub const STOPPED_STAGE: u64 = 4;
pub const RECEIVE: u64 = 3;
pub const SEND: u64 = 2;
pub const REPLY: u64 = 5;
pub const YIELD: u64 = 1;
pub const QUERY: u64 = 0x50554c530004;
pub const READY: u64 = 0x50554c530005;
pub const STOP: u64 = 0x50554c530006;
pub const STOPPED: u64 = 0x50554c530007;
pub const SHUTDOWN: u64 = 0x50554c530003;
pub const TRIGGER_SHUTDOWN: u64 = 0x544553540001;
pub const FAIL: u64 = 0x544553540002;
pub const ACK: u64 = 0x544553540003;
pub const EXIT_RESULT: u64 = 37;
pub const PARAMETER_PREFIX = @sizeOf(u64);
pub const HEADER_BYTES = 3 * @sizeOf(u64);
