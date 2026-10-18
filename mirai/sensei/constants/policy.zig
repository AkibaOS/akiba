//! Single CPU Scheduling Policy

const pool = @import("mirai").thread.constants.pool;

pub const MAX_RECORDS: usize = pool.MAX_THREADS + 1;
pub const QUANTUM_TICKS: u32 = 10;
