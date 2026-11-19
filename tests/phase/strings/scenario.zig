//! Guest Scenario Wire Labels

pub const FILE = "opt/akiba/tests";
pub const ARGUMENT = "name=" ++ FILE ++ ",string={s}";
pub const PHASE_FILE = "opt/akiba/test-phase-channel";
pub const PHASE_VALUE = "1";
pub const PHASE_ARGUMENT = "name=" ++ PHASE_FILE ++ ",string=" ++ PHASE_VALUE;
pub const LIVE_FILE = "opt/akiba/test-live-progress";
pub const LIVE_ARGUMENT = "name=" ++ LIVE_FILE ++ ",string=" ++ PHASE_VALUE;
pub const CANCEL_FILE = "opt/akiba/test-cancel";
pub const CANCEL_ARGUMENT = "name=" ++ CANCEL_FILE ++ ",string=" ++ PHASE_VALUE;
pub const INVALID_PHASE = "Test phase ticket missing or invalid";
pub const BUILD_DATE_FILE = "opt/akiba/test-build-date";
pub const BUILD_DATE_ARGUMENT = "name=" ++ BUILD_DATE_FILE ++ ",string={s}";
pub const FLAG = "-fw_cfg";
pub const CHECKPOINT = "CHECK FATAL PulseDeath\n";
pub const PANIC = "KERNEL PANIC: System Pulse terminated\n";
pub const GROUP = "Pulse termination";
pub const COLLAPSE_GROUP = "Crimson collapse";
pub const COLLAPSE_CHECKPOINT = "CHECK FATAL Collapse\n";
pub const COLLAPSE_MESSAGE = "Selected Crimson test";
pub const COLLAPSE_REASON = "Reason: " ++ COLLAPSE_MESSAGE ++ "\n";
pub const COLLAPSE_BANNER = "AKIBA COLLAPSED";
pub const COLLAPSE_HALT = "System halted. Please restart your computer.";
pub const INVALID = "Invalid guest test scenario";
pub const UNEXPECTED_RETURN = "Expected fatal scenario returned";
