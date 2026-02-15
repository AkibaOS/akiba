//! Kata constants

const memory = @import("memory.zig");

pub const KATA_STACK_TOP: u64 = 0x00007FFFFFF00000;
pub const KATA_STACK_PAGES: u64 = 64;
pub const KATA_STACK_SIZE: u64 = KATA_STACK_PAGES * memory.PAGE_SIZE;
pub const MIRAI_STACK_SIZE: u64 = memory.PAGE_SIZE;

pub const TIMER_TICK_NS: u64 = 1_000_000;
pub const SENSEI_TIME_SLICE: u64 = 10;

pub const STATE_READY: u8 = 0;
pub const STATE_RUNNING: u8 = 1;
pub const STATE_BLOCKED: u8 = 2;
pub const STATE_WAITING: u8 = 3;
pub const STATE_DISSOLVED: u8 = 4;

pub const LETTER_NONE: u8 = 0;
pub const LETTER_NAVIGATE: u8 = 1;

pub const POSTMAN_SEND: u64 = 0;
pub const POSTMAN_READ: u64 = 1;
