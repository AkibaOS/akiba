//! Disk information

const sys = @import("sys");
const types = @import("types.zig");

const ERROR_RESULT: u64 = @bitCast(@as(i64, -1));

pub fn info() ?types.DiskInfo {
    var total: u64 = 0;
    var used: u64 = 0;

    const result = sys.syscall(.diskinfo, .{
        @intFromPtr(&total),
        @intFromPtr(&used),
    });

    if (result == ERROR_RESULT) {
        return null;
    }

    return types.DiskInfo{
        .total = total,
        .used = used,
    };
}
