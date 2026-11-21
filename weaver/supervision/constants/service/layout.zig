//! Ordinary Binary Startup And Guarded Stack Geometry

const memory = @import("common").constants.memory;

pub const STARTUP_BASE: u64 = 0x0000600000000000;
pub const STACK_PAGES: u64 = 16;
pub const STACK_BASE: u64 = memory.layout.USER_SPACE_END + 1 - (STACK_PAGES + 1) * memory.sizes.PAGE_SIZE;
