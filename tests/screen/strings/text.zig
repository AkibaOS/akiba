//! Diagnostic Screen Text

pub const TITLE = "Akiba OS | Build ";
pub const UNKNOWN_DATE = "(date unknown)";
pub const BUILD_DATE_FORMAT = "{d:0>4}-{d:0>2}-{d:0>2}";
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
pub const PERCENT = "{d}%";
pub const LEGEND = "[Enter] Boot Normally | [S] Shut Down | [Esc] Cancel Tests";
