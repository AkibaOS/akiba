//! Serial Oracle Fixtures

pub const VALID = "AKIBA_GUEST_CHECKS_BEGIN\nCHECK GROUP test\nCHECK PASS one\nAKIBA_GUEST_CHECKS_COMPLETE 1\nAkiba Ready\n";
pub const PENDING = "AKIBA_GUEST_CHECKS_BEGIN\nCHECK PASS one\n";
pub const MISSING = "Akiba Ready\n";
pub const INCOMPLETE = "AKIBA_GUEST_CHECKS_BEGIN\nCHECK PASS one\nAkiba Ready\n";
pub const ZERO = "AKIBA_GUEST_CHECKS_BEGIN\nAKIBA_GUEST_CHECKS_COMPLETE 0\nAkiba Ready\n";
pub const MISMATCH = "AKIBA_GUEST_CHECKS_BEGIN\nCHECK PASS one\nAKIBA_GUEST_CHECKS_COMPLETE 2\nAkiba Ready\n";
pub const BAD_COUNT = "AKIBA_GUEST_CHECKS_BEGIN\nAKIBA_GUEST_CHECKS_COMPLETE nope\nAkiba Ready\n";
pub const FAIL = "CHECK FAIL input\n";
pub const PANIC = "KERNEL PANIC: wrong failure\n";
pub const BEGIN = "AKIBA_GUEST_CHECKS_BEGIN\n";
pub const COLLAPSE_VALID = "AKIBA_GUEST_CHECKS_BEGIN\nCHECK FATAL Collapse\nAKIBA COLLAPSED\nReason: Selected Crimson test\nSystem halted. Please restart your computer.\n";
pub const COLLAPSE_UNARMED = "AKIBA_GUEST_CHECKS_BEGIN\nAKIBA COLLAPSED\nReason: Selected Crimson test\nSystem halted. Please restart your computer.\n";
pub const COLLAPSE_WRONG = "AKIBA_GUEST_CHECKS_BEGIN\nCHECK FATAL Collapse\nAKIBA COLLAPSED\nReason: Collapse\nSystem halted. Please restart your computer.\n";
pub const FIRMWARE_VALID = "AKIBA_FIRMWARE_CHECKS_BEGIN\n" ++ "CHECK PASS handoff\n" ** 8 ++ "AKIBA_FIRMWARE_CHECKS_COMPLETE 8\n";
pub const FIRMWARE_EMPTY = "AKIBA_FIRMWARE_CHECKS_BEGIN\nAKIBA_FIRMWARE_CHECKS_COMPLETE 0\n";
pub const FATAL_CRLF = "AKIBA_GUEST_CHECKS_BEGIN\r\nCHECK FATAL PulseDeath\r\nKERNEL PANIC: System Pulse terminated\r\n";
