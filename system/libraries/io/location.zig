//! Location operations

const sys = @import("sys");
const types = @import("types.zig");

const ERROR_RESULT: u64 = @bitCast(@as(i64, -1));

pub fn get(buffer: []u8) types.Error![]u8 {
    const result = sys.syscall(.getlocation, .{
        @intFromPtr(buffer.ptr),
        buffer.len,
    });

    if (result == ERROR_RESULT) {
        return types.Error.GetLocationFailed;
    }

    return buffer[0..@intCast(result)];
}

pub fn set(path: []const u8) types.Error!void {
    const result = sys.syscall(.setlocation, .{
        @intFromPtr(path.ptr),
        path.len,
    });

    if (result == ERROR_RESULT) {
        return types.Error.InvalidPath;
    }
}
