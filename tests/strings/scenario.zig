//! Guest Scenario Wire Labels

pub const FILE = "opt/akiba/tests";
pub const ARGUMENT = "name=" ++ FILE ++ ",string={s}";
pub const FLAG = "-fw_cfg";
pub const CHECKPOINT = "CHECK FATAL PulseDeath\n";
pub const PANIC = "KERNEL PANIC: System Pulse terminated\n";
pub const GROUP = "Pulse termination";
pub const INVALID = "Invalid guest test scenario";
pub const UNEXPECTED_RETURN = "Expected fatal scenario returned";
