//! Uptime information

const sys = @import("sys");

const ERROR_RESULT: u64 = @bitCast(@as(i64, -1));

pub fn get() ?u64 {
    const result = sys.syscall(.uptime, .{});

    if (result == ERROR_RESULT) {
        return null;
    }

    return result;
}
