//! Hikari Page Table Entry Constants

const flags = @import("common").constants.paging.flags;

pub const MAPPING_FLAGS: u64 = flags.PRESENT | flags.WRITABLE | flags.WRITE_THROUGH | flags.CACHE_DISABLED | flags.ACCESSED | flags.DIRTY | flags.PAT_PAGE | flags.GLOBAL | flags.NO_EXECUTE;
pub const HARDWARE_STATE_FLAGS: u64 = flags.ACCESSED | flags.DIRTY;
