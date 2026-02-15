//! Kata Constants - Kata execution and scheduling related constants

const memory = @import("memory.zig");

// ============================================================================
// Kata Stack Configuration
// ============================================================================

/// Kata stack top address (grows downward)
pub const KATA_STACK_TOP: u64 = 0x00007FFFFFF00000;

/// Number of pages allocated for kata stack
pub const KATA_STACK_PAGES: u64 = 64; // 256KB

/// Total kata stack size in bytes
pub const KATA_STACK_SIZE: u64 = KATA_STACK_PAGES * memory.PAGE_SIZE;

/// Mirai (kernel) stack size per kata (one page)
pub const MIRAI_STACK_SIZE: u64 = memory.PAGE_SIZE;

// ============================================================================
// Sensei (Scheduler) Timing Constants
// ============================================================================

/// Timer tick frequency (nanoseconds per tick)
pub const TIMER_TICK_NS: u64 = 1_000_000; // 1ms

/// Sensei time slice (in timer ticks)
pub const SENSEI_TIME_SLICE: u64 = 10; // 10ms

// ============================================================================
// Kata State Values
// ============================================================================

/// Kata is ready to run
pub const STATE_READY: u8 = 0;

/// Kata is currently running
pub const STATE_RUNNING: u8 = 1;

/// Kata is blocked waiting for I/O
pub const STATE_BLOCKED: u8 = 2;

/// Kata is waiting for another kata
pub const STATE_WAITING: u8 = 3;

/// Kata has dissolved (exited)
pub const STATE_DISSOLVED: u8 = 4;

// ============================================================================
// Postman (Letter) Constants
// ============================================================================

/// No letter in inbox
pub const LETTER_NONE: u8 = 0;

/// Navigate (change location) letter
pub const LETTER_NAVIGATE: u8 = 1;

/// Postman mode: send letter to parent
pub const POSTMAN_SEND: u64 = 0;

/// Postman mode: read letter from inbox
pub const POSTMAN_READ: u64 = 1;
