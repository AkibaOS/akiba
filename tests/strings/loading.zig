//! Firmware ELF Loading Regression Labels

pub const GROUP = "CHECK GROUP Hikari ELF allocation\n";

pub const REJECTION = "ELF loading rejects malformed input and unsupported physical limits before allocation";
pub const FALLBACK = "ELF loading falls back from rejected preferred placement to real MaxAddress pages";
pub const COPY = "ELF loading copies exact text read-only and initialized data bytes";
pub const ZERO = "ELF loading clears dirty BSS guard gaps and uninitialized stack segments";
pub const SEGMENTS = "ELF loading relocates all seven physical segments without changing virtual layout or flags";
pub const RELEASE = "ELF loading transfers one exact allocation for caller release through real firmware";
pub const FAILURE = "ELF allocation failure leaves no owned pages or release callbacks";
pub const CLEANUP_FAILED = "ELF loading fixture page release failed";
