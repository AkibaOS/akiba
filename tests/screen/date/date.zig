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
    return std.fmt.bufPrint(buffer, labels.BUILD_DATE_FORMAT, .{ @as(u8, day.day_index) + 1, day.month.numeric(), year.year }) catch null;
}

pub fn valid(value: []const u8) bool {
    if (value.len != inputs.DATE_BYTES) return false;
    for (value) |byte| if (!std.ascii.isDigit(byte)) return false;
    const day = std.fmt.parseInt(u8, value[0..2], 10) catch return false;
    const month = std.fmt.parseInt(u4, value[2..4], 10) catch return false;
    const year = std.fmt.parseInt(std.time.epoch.Year, value[4..], 10) catch return false;
    if (year == 0 or month == 0 or month > 12 or day == 0) return false;
    return day <= std.time.epoch.getDaysInMonth(year, @enumFromInt(month));
}
