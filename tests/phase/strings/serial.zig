//! Cross Target Diagnostic Serial Markers

pub const BEGIN = "AKIBA_GUEST_CHECKS_BEGIN";
pub const COMPLETE = "AKIBA_GUEST_CHECKS_COMPLETE ";
pub const CANCELLED = "AKIBA_GUEST_CHECKS_CANCELLED ";
pub const PASS = "CHECK PASS ";
pub const FAIL = "CHECK FAIL ";
pub const GROUP = "CHECK GROUP ";
pub const DISPLAY_READY = "CHECK DIAGNOSTIC DISPLAY READY\n";
pub const LINE_SEPARATORS = "\r\n";

pub const BEGIN_LINE = BEGIN ++ "\n";
pub const COMPLETE_FORMAT = COMPLETE ++ "%d\n";
pub const CANCELLED_FORMAT = CANCELLED ++ "%d\n";
pub const PASS_FORMAT = PASS ++ "%s\n";
pub const FAIL_FORMAT = FAIL ++ "%s\n";
