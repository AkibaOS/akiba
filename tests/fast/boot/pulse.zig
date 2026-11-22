//! Pulse Installation Contract Regression

const std = @import("std");

const expected = @import("tests").fast.strings.boot.pulse;
const install = @import("shared").location.strings.installed.paths;

pub fn standalone() !void {
    try std.testing.expectEqual(expected.STACKS.len, install.CORE_PARTS.len);
    for (expected.STACKS, install.CORE_PARTS) |wanted, actual| try std.testing.expectEqualStrings(wanted, actual);
    try std.testing.expectEqualStrings(expected.UNIT, install.FLAT_PULSE_UNIT);
    try std.testing.expectEqualStrings(expected.PATH, install.FLAT_PULSE_PATH);
}
