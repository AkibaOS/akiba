//! Test Image Build Date Metadata

const std = @import("std");

const inputs = @import("tests").screen.constants.frame;
const labels = @import("tests").screen.strings.text;

pub fn format(buffer: *[inputs.DATE_BYTES]u8, modified: i128) ?[]const u8 {
    const seconds = @divFloor(modified, std.time.ns_per_s);
    if (seconds < 0 or seconds > inputs.LAST_FOUR_DIGIT_YEAR_SECOND) return null;
    const epoch: std.time.epoch.EpochSeconds = .{ .secs = @intCast(seconds) };
    const year = epoch.getEpochDay().calculateYearDay();
    const day = year.calculateMonthDay();
    return std.fmt.bufPrint(buffer, labels.BUILD_DATE_FORMAT, .{ year.year, day.month.numeric(), @as(u8, day.day_index) + 1 }) catch null;
}

pub fn valid(value: []const u8) bool {
    if (value.len != inputs.DATE_BYTES) return false;
    for (value, 0..) |byte, index| {
        if (index == 4 or index == 7) {
            if (byte != '-') return false;
        } else if (!std.ascii.isDigit(byte)) return false;
    }
    return true;
}
