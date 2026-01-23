//! Memory Constants - Centralized memory addresses and sizes
//! Single source of truth for all memory-related constants

// Memory Layout Constants
pub const PAGE_SIZE: u64 = 4096;
pub const HIGHER_HALF_START: u64 = 0xFFFF800000000000;

// Kernel Memory Layout
pub const KERNEL_START: u64 = 0x100000;
pub const KERNEL_END: u64 = 0x500000;

// User Stack Configuration
pub const USER_STACK_TOP: u64 = 0x00007FFFFFF00000;
pub const USER_STACK_PAGES: u64 = 64; // 256KB stack
pub const USER_STACK_SIZE: u64 = USER_STACK_PAGES * PAGE_SIZE;

// Kernel Stack Configuration
pub const KERNEL_STACK_SIZE: u64 = 4096; // 4KB kernel stack per kata
