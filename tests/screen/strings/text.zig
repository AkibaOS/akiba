//! Diagnostic Screen Text

pub const TITLE = "Akiba OS | Build ";
pub const UNKNOWN_DATE = "(date unknown)";
pub const BUILD_DATE_FORMAT = "{d:0>2}{d:0>2}{d:0>4}";
pub const SUBTITLE = "Running Test Suite...";
pub const FINISHED_SUBTITLE = "Test Suite Completed.";
pub const STARTING = "Starting test suite...";
pub const COMPLETED = "Test suite completed.";
pub const INFO_PREFIX = "[INFO] ";
pub const PASS_PREFIX = "[PASS]";
pub const FAIL_PREFIX = "[FAIL]";
pub const TEST_PREFIX = " Test ";
pub const SPINNER = [_][]const u8{ "[    ]", "[*   ]", "[**  ]", "[*** ]", "[ ***]", "[  **]", "[   *]", "[    ]" };
pub const BAR_START = "[";
pub const BAR_END = "]";
pub const PERCENT = " {d: >3}%";
pub const REPEATED = " (x{d})";
pub const VERIFIED_REFUSALS = " ({d} refusals verified)";
pub const BOOTSTRAP_ROLLBACK = "Bootstrap allocation rollback";
pub const CONTROL_SEPARATOR = " | ";
pub const COMPLETED_LEGEND = "[Enter] Boot Normally" ++ CONTROL_SEPARATOR ++ "[S] Shut Down";
pub const CANCEL_LEGEND = "[Esc] Cancel Tests";
