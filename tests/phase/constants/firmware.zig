//! Shared Firmware Assertion Count

const storage = @import("tests").fixtures.constants.storage;

pub const ASSERTION_COUNT: usize = 63 + storage.ASSERTION_COUNT;
