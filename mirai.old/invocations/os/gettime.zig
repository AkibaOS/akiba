//! GETTIME invocation - Get current unix timestamp

const cmos = @import("../../asm/cmos.zig");
const handler = @import("../handler.zig");
const result = @import("../../utils/types/result.zig");
const sensei = @import("../../kata/sensei/sensei.zig");
const time_const = @import("../../common/constants/time.zig");

var boot_timestamp: u64 = 0;

pub fn set_boot_timestamp(timestamp: u64) void {
    boot_timestamp = timestamp;
}

pub fn invoke(ctx: *handler.InvocationContext) void {
    if (boot_timestamp == 0) {
        const rtc_time = read_rtc();
        result.set_value(ctx, rtc_time);
    } else {
        const ticks = sensei.get_tick_count();
        const seconds = ticks / time_const.TICKS_PER_SECOND;
        result.set_value(ctx, boot_timestamp + seconds);
    }
}

fn read_rtc() u64 {
    const sec = cmos.bcd_to_bin(cmos.read_seconds());
    const min = cmos.bcd_to_bin(cmos.read_minutes());
    const hr = cmos.bcd_to_bin(cmos.read_hours());
    const d = cmos.bcd_to_bin(cmos.read_day());
    const m = cmos.bcd_to_bin(cmos.read_month());
    const y = cmos.bcd_to_bin(cmos.read_year());
    const c = cmos.bcd_to_bin(cmos.read_century());

    const full_year = @as(u64, c) * 100 + @as(u64, y);

    return to_unix_timestamp(full_year, m, d, hr, min, sec);
}

fn to_unix_timestamp(year: u64, month: u8, day: u8, hour: u8, minute: u8, second: u8) u64 {
    const DAYS_BEFORE_MONTH = [_]u64{ 0, 31, 59, 90, 120, 151, 181, 212, 243, 273, 304, 334 };

    var days: u64 = 0;

    // Days from years since 1970
    var y = time_const.EPOCH_YEAR;
    while (y < year) : (y += 1) {
        days += if (is_leap(y)) 366 else 365;
    }

    // Days from months
    if (month > 0 and month <= 12) {
        days += DAYS_BEFORE_MONTH[month - 1];
    }

    // Add leap day if past February in a leap year
    if (month > 2 and is_leap(year)) {
        days += 1;
    }

    // Days in current month
    days += day - 1;

    return days * time_const.SECONDS_PER_DAY +
        @as(u64, hour) * time_const.SECONDS_PER_HOUR +
        @as(u64, minute) * time_const.SECONDS_PER_MINUTE +
        @as(u64, second);
}

fn is_leap(year: u64) bool {
    return (year % 4 == 0 and year % 100 != 0) or (year % 400 == 0);
}
