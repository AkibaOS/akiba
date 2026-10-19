//! User Thread Stack Limits

pub const MAX_STACK_PAGES: u64 = 16;
pub const ENTRY_STACK_BYTES: u64 = 2 * @sizeOf(u64);
