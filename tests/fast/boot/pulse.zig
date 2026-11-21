//! Pulse Installation Contract Regression

const std = @import("std");

const expected = @import("tests").fast.strings.boot.pulse;
const install = @import("shared").pulse.strings.install;

pub fn standalone() !void {
    try std.testing.expectEqual(expected.STACKS.len, install.STACKS.len);
    for (expected.STACKS, install.STACKS) |wanted, actual| try std.testing.expectEqualStrings(wanted, actual);
    try std.testing.expectEqualStrings(expected.UNIT, install.UNIT);
    try std.testing.expectEqualStrings(expected.PATH, install.PATH);
}
