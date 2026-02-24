//! Print utilities

const colors = @import("colors");
const io = @import("io");

pub fn print(text: []const u8) void {
    _ = io.mark(io.stream, text, colors.white) catch {};
}

pub fn println(text: []const u8) void {
    _ = io.mark(io.stream, text, colors.white) catch {};
    _ = io.mark(io.stream, "\n", colors.white) catch {};
}

pub fn color(text: []const u8, col: u32) void {
    _ = io.mark(io.stream, text, col) catch {};
}

pub fn colorln(text: []const u8, col: u32) void {
    _ = io.mark(io.stream, text, col) catch {};
    _ = io.mark(io.stream, "\n", colors.white) catch {};
}

pub fn printf(comptime fmt: []const u8, args: anytype, buf: []u8) void {
    const len = formatBuf(fmt, args, buf);
    _ = io.mark(io.stream, buf[0..len], colors.white) catch {};
}

pub fn colorf(comptime fmt: []const u8, args: anytype, buf: []u8, col: u32) void {
    const len = formatBuf(fmt, args, buf);
    _ = io.mark(io.stream, buf[0..len], col) catch {};
}

fn formatBuf(comptime fmt: []const u8, args: anytype, buf: []u8) usize {
    var pos: usize = 0;
    comptime var arg_idx: usize = 0;

    comptime var i: usize = 0;
    inline while (i < fmt.len) {
        if (fmt[i] == '{' and i + 1 < fmt.len and fmt[i + 1] == '}') {
            const arg = args[arg_idx];
            const T = @TypeOf(arg);

            if (T == []const u8 or T == []u8) {
                for (arg) |c| {
                    if (pos >= buf.len) break;
                    buf[pos] = c;
                    pos += 1;
                }
            } else if (@typeInfo(T) == .int or @typeInfo(T) == .comptime_int) {
                pos += writeInt(@intCast(arg), buf[pos..]);
            }

            arg_idx += 1;
            i += 2;
        } else {
            if (pos < buf.len) {
                buf[pos] = fmt[i];
                pos += 1;
            }
            i += 1;
        }
    }

    return pos;
}

fn writeInt(num: u64, buf: []u8) usize {
    if (num == 0) {
        if (buf.len > 0) {
            buf[0] = '0';
            return 1;
        }
        return 0;
    }

    var temp: [20]u8 = undefined;
    var n = num;
    var i: usize = 0;

    while (n > 0) : (i += 1) {
        temp[i] = @as(u8, @intCast(n % 10)) + '0';
        n /= 10;
    }

    var written: usize = 0;
    while (i > 0 and written < buf.len) {
        i -= 1;
        buf[written] = temp[i];
        written += 1;
    }

    return written;
}
