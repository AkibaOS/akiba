//! Manual Guest Runner Limits

pub const POLL_NS: u64 = 50_000_000;
pub const START_NS: u64 = 60_000_000_000;
pub const SNAPSHOT_NS: u64 = 60_000_000_000;
pub const CHECK_NS: u64 = 120_000_000_000;
pub const QUIT_NS: u64 = 15_000_000_000;
pub const PROTOCOL_NS: u64 = 5_000_000_000;
pub const RECEIVE_MS: u32 = 2000;
pub const RECEIVE_SECONDS: i64 = 2;
pub const MAX_PACKET_BYTES: usize = 65536;
pub const MAX_PACKETS: usize = 1024;
pub const MAX_SERIAL_BYTES: usize = 1024 * 1024;
pub const MAX_TOOL_BYTES: usize = 1024 * 1024;
pub const FAILURE_TAIL_LINES: usize = 48;
pub const JOB_KILL_ON_CLOSE: u32 = 0x2000;
pub const JOB_EXTENDED_LIMITS: u32 = 9;
pub const JOB_ACCOUNTING: u32 = 1;
pub const WAIT_SIGNALED: u32 = 0;
pub const WAIT_TIMEOUT: u32 = 0x102;
pub const RESUME_FAILED: u32 = 0xffffffff;
pub const CONSOLE_INTERRUPT: u32 = 0;
pub const CONSOLE_BREAK: u32 = 1;
pub const WAIT_ID_PID: c_uint = 1;
pub const DARWIN_WAIT_EXITED: c_int = 0x04;
pub const DARWIN_WAIT_NOWAIT: c_int = 0x20;
