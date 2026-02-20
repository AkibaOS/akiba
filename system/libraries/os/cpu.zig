//! CPU information

const sys = @import("sys");
const types = @import("types.zig");

const ERROR_RESULT: u64 = @bitCast(@as(i64, -1));

pub fn info(buffer: []u8) ?[]const u8 {
    const result = sys.syscall(.cpuinfo, .{
        @intFromPtr(buffer.ptr),
        buffer.len,
    });

    if (result == ERROR_RESULT or result == 0) {
        return null;
    }

    return buffer[0..@intCast(result)];
}
