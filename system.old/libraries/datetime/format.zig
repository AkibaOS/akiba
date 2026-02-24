//! Date/time formatting

const time = @import("time.zig");

const MONTH_NAMES = [_][]const u8{ "Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec" };

pub fn date(timestamp: u64, buf: []u8) []const u8 {
    if (timestamp == 0) {
        const default = "01 Jan 1970 00:00";
        for (default, 0..) |c, i| {
            buf[i] = c;
        }
        return buf[0..default.len];
    }

    const dt = time.parts(timestamp);
    var pos: usize = 0;

    // Day
    if (dt.day < 10) {
        buf[pos] = '0';
        pos += 1;
    }
    pos += writeInt(dt.day, buf[pos..]);

    buf[pos] = ' ';
    pos += 1;

    // Month name
    const month_idx = if (dt.month > 0 and dt.month <= 12) dt.month - 1 else 0;
    for (MONTH_NAMES[month_idx]) |c| {
        buf[pos] = c;
        pos += 1;
    }

    buf[pos] = ' ';
    pos += 1;

    // Year
    pos += writeInt(dt.year, buf[pos..]);

    buf[pos] = ' ';
    pos += 1;

    // Hour
    if (dt.hour < 10) {
        buf[pos] = '0';
        pos += 1;
    }
    pos += writeInt(dt.hour, buf[pos..]);

    buf[pos] = ':';
    pos += 1;

    // Minute
    if (dt.minute < 10) {
        buf[pos] = '0';
        pos += 1;
    }
    pos += writeInt(dt.minute, buf[pos..]);

    return buf[0..pos];
}

pub fn duration(total_secs: u64, buf: []u8) []const u8 {
    const hours = total_secs / 3600;
    const mins = (total_secs % 3600) / 60;
    const secs = total_secs % 60;

    var pos: usize = 0;

    pos += writeInt(hours, buf[pos..]);
    buf[pos] = 'h';
    pos += 1;
    buf[pos] = ' ';
    pos += 1;

    pos += writeInt(mins, buf[pos..]);
    buf[pos] = 'm';
    pos += 1;
    buf[pos] = ' ';
    pos += 1;

    pos += writeInt(secs, buf[pos..]);
    buf[pos] = 's';
    pos += 1;

    return buf[0..pos];
}

fn writeInt(value: u64, buf: []u8) usize {
    if (value == 0) {
        buf[0] = '0';
        return 1;
    }

    var temp: [20]u8 = undefined;
    var len: usize = 0;
    var v = value;

    while (v > 0) : (v /= 10) {
        temp[len] = @intCast('0' + (v % 10));
        len += 1;
    }

    for (0..len) |i| {
        buf[i] = temp[len - 1 - i];
    }

    return len;
}
