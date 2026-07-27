//! Fault Error Code Bits

pub const PAGE_FAULT_PRESENT: u64 = 1 << 0;
pub const PAGE_FAULT_WRITE: u64 = 1 << 1;
pub const PAGE_FAULT_USER: u64 = 1 << 2;
pub const PAGE_FAULT_RESERVED_WRITE: u64 = 1 << 3;
pub const PAGE_FAULT_INSTRUCTION_FETCH: u64 = 1 << 4;

pub const SELECTOR_EXTERNAL: u64 = 1 << 0;
pub const SELECTOR_TABLE_SHIFT: u6 = 1;
pub const SELECTOR_TABLE_MASK: u64 = 0x3;
pub const SELECTOR_INDEX_SHIFT: u6 = 3;
pub const SELECTOR_INDEX_MASK: u64 = 0x1FFF;
