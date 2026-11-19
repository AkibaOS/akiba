//! EFI Diagnostic Menu Summary Text

pub const SUITE_PASSED = "suite passed ({d} checks verified)";
pub const SUITE_FAILED = "suite failed";
pub const VERIFIED_CHECKS = "Verified checks in passing phases: {d}";
pub const PHASE_FAILURES = "Failed phases: {d} | Incomplete: {d}";
pub const PHASE_NAMES = [_][]const u8{ "Standard", "Pulse termination", "EFI firmware", "Hardware devices", "Crimson collapse" };
pub const INCOMPLETE_NAMES = names: {
    var labels: [PHASE_NAMES.len][]const u8 = undefined;
    for (PHASE_NAMES, 0..) |name, index| labels[index] = name ++ " (incomplete)";
    break :names labels;
};
pub const FAILURE = "CHECK FAIL Menu: ";
pub const NEWLINE = "\n";
