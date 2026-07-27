//! Crimson Limits

pub const EXCEPTION_TYPE_COUNT: usize = 10;
pub const MAX_KATAS: usize = 256;
pub const MAX_THREADS: usize = 1024;
pub const MAX_CORPSES: usize = 16;
pub const MAX_MODULES: usize = 32;

pub const MESSAGE_CAPACITY: usize = 256;
pub const MODULE_NAME_CAPACITY: usize = 64;
pub const IDENTITY_NAME_CAPACITY: usize = 32;
pub const SNAPSHOT_SIZE: usize = 4096;

pub const RENDER_MAX_STACK_DEPTH: usize = 20;
pub const RENDER_BYTES_PER_ROW: usize = 16;
pub const RENDER_INSTRUCTION_BYTES: usize = 8;
