//! Firmware Handoff Regression Labels

pub const BEGIN = "AKIBA_FIRMWARE_CHECKS_BEGIN\n";
pub const COMPLETE = "AKIBA_FIRMWARE_CHECKS_COMPLETE ";
pub const GROUP = "CHECK GROUP Hikari handoff client logic with scripted ExitBootServices; firmware remains active\n";
pub const PASS = "CHECK PASS ";
pub const FAIL = "CHECK FAIL ";
pub const NEWLINE = "\n";
pub const COUNT = "{d}";
pub const COUNT_MISMATCH = "Firmware assertion count mismatch";
pub const FORMAT_FAILED = "Firmware count formatting failed";
pub const CLEANUP_FAILED = "Firmware fixture page release failed";
pub const INITIALIZE_ROLLBACK = "handoff initialization rolls back the stack when parameter allocation fails";
pub const INITIALIZE_RELEASE = "handoff initialization publishes valid parameters and releases owned pages once";
pub const MAP_GROWTH = "handoff grows and replaces real map buffers and publishes descriptor metadata";
pub const MAP_COUNT = "handoff publishes more than former 512 descriptors with real firmware-backed storage";
pub const MAP_STRIDE = "handoff accepts representable extended descriptor strides without a page-sized ceiling";
pub const MAP_BYTES = "handoff sizes actual map backing beyond the former two-megabyte workspace";
pub const EXITED_RELEASE = "scripted exit success leaves Exited ownership frozen until fixture release";
pub const MAP_METADATA = "handoff rejects invalid descriptor stride and version before attempting exit";
pub const STALE_RETRY = "handoff retries a stale scripted map key with a fresh map key";
pub const RETRY_BOUND = "handoff bounds stale key retries and permits cleanup after failure";
pub const GROWTH_ROLLBACK = "handoff retains the old map and releases its replacement when old map release fails";
