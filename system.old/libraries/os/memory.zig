//! Memory information

const sys = @import("sys");
const types = @import("types.zig");

const ERROR_RESULT: u64 = @bitCast(@as(i64, -1));

pub fn info() ?types.MemInfo {
    var total: u64 = 0;
    var used: u64 = 0;
    var free: u64 = 0;

    const result = sys.syscall(.meminfo, .{
        @intFromPtr(&total),
        @intFromPtr(&used),
        @intFromPtr(&free),
    });

    if (result == ERROR_RESULT) {
        return null;
    }

    return types.MemInfo{
        .total = total,
        .used = used,
        .free = free,
    };
}
