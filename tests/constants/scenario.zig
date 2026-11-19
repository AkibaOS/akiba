//! Diagnostic Phase UART Bounds

pub const PHASE_PORT: u16 = 0x2f8;
pub const PHASE_RECEIVE_ERRORS: u8 = 0x1e;
pub const PHASE_POLL_LIMIT: usize = 10_000_000;
