//! Date formatting

const int = @import("int.zig");

const SECONDS_PER_DAY: u64 = 86400;
const SECONDS_PER_HOUR: u64 = 3600;
const SECONDS_PER_MINUTE: u64 = 60;
const DAYS_PER_4_YEARS: u64 = 1461;

const MONTH_NAMES = [_][]const u8{ "Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec" };
const DAYS_NORMAL = [_]u64{ 31, 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31 };
const DAYS_LEAP = [_]u64{ 31, 29, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31 };

pub fn format(timestamp: u64, buf: []u8) []u8 {
    if (timestamp == 0) {
        const default = "01 Jan 1970 00:00";
        for (default, 0..) |c, i| {
            buf[i] = c;
        }
        return buf[0..default.len];
    }

    const days_since_epoch = timestamp / SECONDS_PER_DAY;
    const seconds_today = timestamp % SECONDS_PER_DAY;
    const hours = seconds_today / SECONDS_PER_HOUR;
    const minutes = (seconds_today % SECONDS_PER_HOUR) / SECONDS_PER_MINUTE;

    var year: u64 = 1970;
    var remaining_days = days_since_epoch;

    const four_year_cycles = remaining_days / DAYS_PER_4_YEARS;
    year += four_year_cycles * 4;
    remaining_days = remaining_days % DAYS_PER_4_YEARS;

    while (remaining_days >= 365) {
        const is_leap = isLeapYear(year);
        const days_this_year: u64 = if (is_leap) 366 else 365;
        if (remaining_days >= days_this_year) {
            remaining_days -= days_this_year;
            year += 1;
        } else {
            break;
        }
    }

    const is_leap = isLeapYear(year);
    const days_in_months = if (is_leap) DAYS_LEAP else DAYS_NORMAL;

    var month: usize = 0;
    var day: u64 = remaining_days + 1;

    for (days_in_months, 0..) |days, m| {
        if (day <= days) {
            month = m;
            break;
        }
        day -= days;
    }

    var pos: usize = 0;

    if (day < 10) {
        buf[pos] = '0';
        pos += 1;
    }
    const day_str = int.toStr(day, buf[pos..]);
    pos += day_str.len;

    buf[pos] = ' ';
    pos += 1;

    for (MONTH_NAMES[month]) |c| {
        buf[pos] = c;
        pos += 1;
    }

    buf[pos] = ' ';
    pos += 1;

    const year_str = int.toStr(year, buf[pos..]);
    pos += year_str.len;

    buf[pos] = ' ';
    pos += 1;

    if (hours < 10) {
        buf[pos] = '0';
        pos += 1;
    }
    const hour_str = int.toStr(hours, buf[pos..]);
    pos += hour_str.len;

    buf[pos] = ':';
    pos += 1;

    if (minutes < 10) {
        buf[pos] = '0';
        pos += 1;
    }
    const min_str = int.toStr(minutes, buf[pos..]);
    pos += min_str.len;

    return buf[0..pos];
}

fn isLeapYear(year: u64) bool {
    return (year % 4 == 0 and year % 100 != 0) or (year % 400 == 0);
}
