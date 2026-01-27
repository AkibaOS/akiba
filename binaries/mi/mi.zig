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

export fn _start() noreturn {
    // TODO: Parse command line arguments when implemented
    // For now, default to root "/"
    const target_path: []const u8 = "/";

    display_stack(target_path) catch |err| {
        mark_error(@errorName(err));
        akiba.kata.exit(1);
    };
    akiba.kata.exit(0);
}

fn display_stack(path: []const u8) !void {
    var entries: [128]akiba.io.StackEntry = undefined;
    const count = akiba.io.viewstack(path, &entries) catch 0;

    // Beautiful header
    _ = akiba.io.mark(akiba.io.stream, "\n  ", Color.white) catch 0;
    _ = akiba.io.mark(akiba.io.stream, path, Color.cyan) catch 0;
    _ = akiba.io.mark(akiba.io.stream, "\n  ", Color.white) catch 0;
    for (0..60) |_| {
        _ = akiba.io.mark(akiba.io.stream, "─", Color.blue) catch 0;
    }
    _ = akiba.io.mark(akiba.io.stream, "\n", Color.white) catch 0;

    var stack_count: usize = 0;
    var unit_count: usize = 0;
    var total_size: u64 = 0;

    for (0..count) |i| {
        const entry = &entries[i];
        const identity = entry.identity[0..entry.identity_len];

        if (entry.is_stack) {
            stack_count += 1;
            _ = akiba.io.mark(akiba.io.stream, "  ", Color.white) catch 0;
            _ = akiba.io.mark(akiba.io.stream, "[]", Color.blue) catch 0;
            _ = akiba.io.mark(akiba.io.stream, "  ", Color.white) catch 0;
            _ = akiba.io.mark(akiba.io.stream, identity, Color.cyan) catch 0;
            _ = akiba.io.mark(akiba.io.stream, "/", Color.blue) catch 0;

            // Show stack size
            var buf: [32]u8 = undefined;
            const size_str = format_size(entry.size, &buf);
            const padding = calculate_padding(identity.len + 4);
            for (0..padding) |_| {
                _ = akiba.io.mark(akiba.io.stream, " ", Color.white) catch 0;
            }
            _ = akiba.io.mark(akiba.io.stream, size_str, Color.blue) catch 0;
            _ = akiba.io.mark(akiba.io.stream, "\n", Color.white) catch 0;
        } else {
            unit_count += 1;
            total_size += entry.size;

            _ = akiba.io.mark(akiba.io.stream, "  ", Color.white) catch 0;
            _ = akiba.io.mark(akiba.io.stream, "*", Color.yellow) catch 0;
            _ = akiba.io.mark(akiba.io.stream, "  ", Color.white) catch 0;
            _ = akiba.io.mark(akiba.io.stream, identity, Color.white) catch 0;

            var buf: [32]u8 = undefined;
            const size_str = format_size(entry.size, &buf);
            const padding = calculate_padding(identity.len + 3);

            for (0..padding) |_| {
                _ = akiba.io.mark(akiba.io.stream, " ", Color.white) catch 0;
            }

            _ = akiba.io.mark(akiba.io.stream, size_str, Color.green) catch 0;
            _ = akiba.io.mark(akiba.io.stream, "\n", Color.white) catch 0;
        }
    }

    // Footer separator and summary
    if (count > 0) {
        _ = akiba.io.mark(akiba.io.stream, "\n  ", Color.white) catch 0;
        for (0..60) |_| {
            _ = akiba.io.mark(akiba.io.stream, "─", Color.blue) catch 0;
        }
        _ = akiba.io.mark(akiba.io.stream, "\n  ", Color.white) catch 0;

        var buf: [16]u8 = undefined;
        const stack_str = int_to_str(stack_count, &buf);
        _ = akiba.io.mark(akiba.io.stream, stack_str, Color.cyan) catch 0;
        _ = akiba.io.mark(akiba.io.stream, " stacks  ", Color.gray) catch 0;

        const unit_str = int_to_str(unit_count, &buf);
        _ = akiba.io.mark(akiba.io.stream, unit_str, Color.yellow) catch 0;
        _ = akiba.io.mark(akiba.io.stream, " units  ", Color.gray) catch 0;

        var size_buf: [32]u8 = undefined;
        const total_str = format_size(total_size, &size_buf);
        _ = akiba.io.mark(akiba.io.stream, total_str, Color.green) catch 0;

        _ = akiba.io.mark(akiba.io.stream, "\n\n", Color.white) catch 0;
    }
}

fn calculate_padding(identity_len: usize) usize {
    const target_col: usize = 40;
    if (identity_len >= target_col) return 2;
    return target_col - identity_len;
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

    // Reverse
    var j: usize = 0;
    while (j < i / 2) : (j += 1) {
        const tmp = buf[j];
        buf[j] = buf[i - 1 - j];
        buf[i - 1 - j] = tmp;
    }

    return buf[0..i];
}

fn mark_error(msg: []const u8) void {
    _ = akiba.io.mark(akiba.io.trace, "mi: ", Color.red) catch 0;
    _ = akiba.io.mark(akiba.io.trace, msg, Color.white) catch 0;
    _ = akiba.io.mark(akiba.io.trace, "\n", Color.white) catch 0;
}
