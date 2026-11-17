//! Stable Storage Regression Labels

pub const NAME = "memory-pool";
pub const PAGE_NAME = "memory-page-pool";
pub const TERMINAL_NAME = "memory-terminal-pool";
pub const INVALID_NAME = "memory-invalid-pool";
pub const GROWTH = "typed storage retains aligned values and lifetime witnesses beyond former populations";
pub const ITERATION = "typed storage supports successor-first removal while walking live values";
pub const MEMBERSHIP = "typed storage rejects interior foreign and freed values without changing live neighbors";
pub const COPIED = "copied initialized storage cannot mutate another store's records";
pub const LIVE_RELEASE = "typed storage refuses destruction while values remain live";
pub const LIFETIME = "recycled value addresses expose a fresh nonwrapping lifetime witness";
pub const REINITIALIZED = "typed storage retains identity history across backing and zone recreation";
pub const FAILURE = "failed typed storage expansion preserves existing values and accounting";
pub const RECOVERY = "typed storage recovers after failed expansion without allocating during release";
pub const EXHAUSTED = "typed storage refuses lifetime counter wrap even after reinitialization";
pub const INVALID = "typed storage rejects unsupported value geometry before allocating";
pub const ZONE_LIFETIME = "zone destruction rejects permanent and unknown descriptors before dereference";
