//! mi - Professional stack viewer for Akiba OS

const akiba = @import("akiba");

const Color = struct {
    const white: u32 = 0x00FFFFFF;
    const cyan: u32 = 0x0000FFFF;
    const blue: u32 = 0x004488DD;
    const green: u32 = 0x0000DD88;
    const yellow: u32 = 0x00DDDD00;
    const gray: u32 = 0x00777777;
    const purple: u32 = 0x00BB88FF;
    const red: u32 = 0x00FF4444;
};

const PERM_OWNER: u8 = 1;
const PERM_WORLD: u8 = 2;
const PERM_READ_ONLY: u8 = 3;

export fn main(pc: u32, pv: [*]const [*:0]const u8) u8 {
    // Use first argument as path, or default to ""
    var target_path: []const u8 = "";

    if (pc > 1) {
        // Get pv[1] as the target path
        const arg = pv[1];
        var len: usize = 0;
        while (arg[len] != 0) : (len += 1) {}
        target_path = arg[0..len];
    }

    display_stack(target_path) catch |err| {
        mark_error(@errorName(err));
        return 1;
    };

    return 0;
}

fn display_stack(path: []const u8) !void {
    var entries: [128]akiba.io.StackEntry = undefined;
    const count = akiba.io.viewstack(path, &entries) catch {
        // Path doesn't exist or isn't a directory
        _ = akiba.io.mark(akiba.io.stream, "mi: cannot access '", Color.red) catch 0;
        _ = akiba.io.mark(akiba.io.stream, path, Color.white) catch 0;
        _ = akiba.io.mark(akiba.io.stream, "': No such stack.\n", Color.red) catch 0;
        return;
    };

    // Check for empty directory (valid directory with 0 entries)
    if (count == 0) {
        _ = akiba.io.mark(akiba.io.stream, path, Color.cyan) catch 0;
        _ = akiba.io.mark(akiba.io.stream, " is empty.\n", Color.gray) catch 0;
        return;
    }

    // Calculate max widths for each column
    var max_access_len: usize = 6;
    var max_size_len: usize = 4;
    var max_owner_len: usize = 7;
    var max_date_len: usize = 8;
    const formatted_date_len: usize = 19;
    if (formatted_date_len > max_date_len) max_date_len = formatted_date_len;

    for (0..count) |i| {
        const entry = &entries[i];
        const perms = get_permissions(entry.permission_type);
        if (perms.len > max_access_len) max_access_len = perms.len;

        var size_buf: [32]u8 = undefined;
        const size_str = format_size(entry.size, &size_buf);
        if (size_str.len > max_size_len) max_size_len = size_str.len;

        if (entry.owner_name_len > max_owner_len) {
            max_owner_len = entry.owner_name_len;
        }
    }

    // Print header
    _ = akiba.io.mark(akiba.io.stream, "Access", Color.white) catch 0;
    print_padding(max_access_len - 6 + 2);
    _ = akiba.io.mark(akiba.io.stream, "Size", Color.white) catch 0;
    print_padding(max_size_len - 4 + 2);
    _ = akiba.io.mark(akiba.io.stream, "Persona", Color.white) catch 0;
    print_padding(max_owner_len - 7 + 3);
    _ = akiba.io.mark(akiba.io.stream, "Modified", Color.white) catch 0;
    print_padding(max_date_len - 8 + 1);
    _ = akiba.io.mark(akiba.io.stream, "Name\n", Color.white) catch 0;

    var stack_count: usize = 0;
    var unit_count: usize = 0;
    var total_size: u64 = 0;

    for (0..count) |i| {
        const entry = &entries[i];
        const identity = entry.identity[0..entry.identity_len];
        const owner = entry.owner_name[0..entry.owner_name_len];

        const perms = get_permissions(entry.permission_type);
        _ = akiba.io.mark(akiba.io.stream, perms, Color.cyan) catch 0;
        print_padding(max_access_len - perms.len + 2);

        var size_buf: [32]u8 = undefined;
        const size_str = format_size(entry.size, &size_buf);
        _ = akiba.io.mark(akiba.io.stream, size_str, Color.green) catch 0;
        print_padding(max_size_len - size_str.len + 2);

        _ = akiba.io.mark(akiba.io.stream, owner, Color.yellow) catch 0;
        print_padding(max_owner_len - owner.len + 3);

        format_date(entry.modified_time);
        print_padding(1);

        if (entry.is_stack) {
            stack_count += 1;
            total_size += entry.size;
            _ = akiba.io.mark(akiba.io.stream, identity, Color.cyan) catch 0;
            _ = akiba.io.mark(akiba.io.stream, "/", Color.blue) catch 0;
        } else {
            unit_count += 1;
            total_size += entry.size;
            _ = akiba.io.mark(akiba.io.stream, identity, Color.white) catch 0;
        }
        _ = akiba.io.mark(akiba.io.stream, "\n", Color.white) catch 0;
    }

    _ = akiba.io.mark(akiba.io.stream, "\n", Color.white) catch 0;
    // Summary
    var buf: [16]u8 = undefined;
    _ = akiba.io.mark(akiba.io.stream, int_to_str(stack_count, &buf), Color.gray) catch 0;
    _ = akiba.io.mark(akiba.io.stream, " stacks  ", Color.gray) catch 0;
    _ = akiba.io.mark(akiba.io.stream, int_to_str(unit_count, &buf), Color.gray) catch 0;
    _ = akiba.io.mark(akiba.io.stream, " units  ", Color.gray) catch 0;
    var size_buf: [32]u8 = undefined;
    _ = akiba.io.mark(akiba.io.stream, format_size(total_size, &size_buf), Color.gray) catch 0;
    _ = akiba.io.mark(akiba.io.stream, "\n", Color.white) catch 0;
}

fn get_permissions(perm_type: u8) []const u8 {
    return switch (perm_type) {
        PERM_OWNER => "Owner",
        PERM_WORLD => "World",
        PERM_READ_ONLY => "Read Only",
        else => "Owner",
    };
}

fn print_padding(count: usize) void {
    var i: usize = 0;
    while (i < count) : (i += 1) {
        _ = akiba.io.mark(akiba.io.stream, " ", Color.white) catch {};
    }
}

fn format_date(timestamp: u64) void {
    if (timestamp == 0) {
        _ = akiba.io.mark(akiba.io.stream, " 1 Jan 1970 00:00  ", Color.blue) catch 0;
        return;
    }
    const SECONDS_PER_DAY: u64 = 86400;
    const SECONDS_PER_HOUR: u64 = 3600;
    const SECONDS_PER_MINUTE: u64 = 60;
    const days_since_epoch = timestamp / SECONDS_PER_DAY;
    const seconds_today = timestamp % SECONDS_PER_DAY;
    const hours = seconds_today / SECONDS_PER_HOUR;
    const minutes = (seconds_today % SECONDS_PER_HOUR) / SECONDS_PER_MINUTE;
    const DAYS_PER_4_YEARS: u64 = 1461;
    var year: u64 = 1970;
    var remaining_days = days_since_epoch;
    const four_year_cycles = remaining_days / DAYS_PER_4_YEARS;
    year += four_year_cycles * 4;
    remaining_days = remaining_days % DAYS_PER_4_YEARS;
    while (remaining_days >= 365) {
        const is_leap = (year % 4 == 0 and year % 100 != 0) or (year % 400 == 0);
        const days_this_year: u64 = if (is_leap) 366 else 365;
        if (remaining_days >= days_this_year) {
            remaining_days -= days_this_year;
            year += 1;
        } else {
            break;
        }
    }
    const is_leap = (year % 4 == 0 and year % 100 != 0) or (year % 400 == 0);
    const days_in_months = if (is_leap) [_]u64{ 31, 29, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31 } else [_]u64{ 31, 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31 };
    const month_names = [_][]const u8{ "Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec" };
    var month: usize = 0;
    var day: u64 = remaining_days + 1;
    for (days_in_months, 0..) |days, m| {
        if (day <= days) {
            month = m;
            break;
        }
        day -= days;
    }
    var buf: [20]u8 = undefined;
    var pos: usize = 0;
    if (day < 10) {
        buf[pos] = '0';
        pos += 1;
    }
    const day_str = int_to_str(day, buf[pos..]);
    pos += day_str.len;
    buf[pos] = ' ';
    pos += 1;
    for (month_names[month]) |c| {
        buf[pos] = c;
        pos += 1;
    }
    buf[pos] = ' ';
    pos += 1;
    const year_str = int_to_str(year, buf[pos..]);
    pos += year_str.len;
    buf[pos] = ' ';
    pos += 1;
    if (hours < 10) {
        buf[pos] = '0';
        pos += 1;
    }
    const hour_str = int_to_str(hours, buf[pos..]);
    pos += hour_str.len;
    buf[pos] = ':';
    pos += 1;
    if (minutes < 10) {
        buf[pos] = '0';
        pos += 1;
    }
    const min_str = int_to_str(minutes, buf[pos..]);
    pos += min_str.len;
    buf[pos] = ' ';
    pos += 1;
    buf[pos] = ' ';
    pos += 1;
    _ = akiba.io.mark(akiba.io.stream, buf[0..pos], Color.blue) catch 0;
}

fn format_size(size: u64, buf: []u8) []u8 {
    if (size < 1024) {
        const s = int_to_str(size, buf);
        buf[s.len] = 'B';
        return buf[0 .. s.len + 1];
    } else if (size < 1024 * 1024) {
        const kb = size / 1024;
        const s = int_to_str(kb, buf);
        buf[s.len] = 'K';
        buf[s.len + 1] = 'B';
        return buf[0 .. s.len + 2];
    } else if (size < 1024 * 1024 * 1024) {
        const mb = size / (1024 * 1024);
        const s = int_to_str(mb, buf);
        buf[s.len] = 'M';
        buf[s.len + 1] = 'B';
        return buf[0 .. s.len + 2];
    } else {
        const gb = size / (1024 * 1024 * 1024);
        const s = int_to_str(gb, buf);
        buf[s.len] = 'G';
        buf[s.len + 1] = 'B';
        return buf[0 .. s.len + 2];
    }
}

fn int_to_str(num: usize, buf: []u8) []u8 {
    if (num == 0) {
        buf[0] = '0';
        return buf[0..1];
    }
    var n = num;
    var i: usize = 0;
    while (n > 0) : (i += 1) {
        buf[i] = @as(u8, @intCast((n % 10) + '0'));
        n /= 10;
    }
    var j: usize = 0;
    while (j < i / 2) : (j += 1) {
        const tmp = buf[j];
        buf[j] = buf[i - 1 - j];
        buf[i - 1 - j] = tmp;
    }
    return buf[0..i];
}

fn mark_error(msg: []const u8) void {
    _ = akiba.io.mark(akiba.io.trace, "mi: ", Color.white) catch 0;
    _ = akiba.io.mark(akiba.io.trace, msg, Color.white) catch 0;
    _ = akiba.io.mark(akiba.io.trace, "\n", Color.white) catch 0;
}
