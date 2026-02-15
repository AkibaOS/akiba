//! Letter (postman) operations

const sys = @import("sys");
const types = @import("types.zig");

const ERROR_RESULT: u64 = @bitCast(@as(i64, -1));

const MODE_SEND: u64 = 0;
const MODE_READ: u64 = 1;

pub fn send(letter_type: u8, data: []const u8) types.Error!void {
    const result = sys.syscall(.postman, .{
        MODE_SEND,
        @as(u64, letter_type),
        @intFromPtr(data.ptr),
        data.len,
    });

    if (result == ERROR_RESULT) {
        return types.Error.SendFailed;
    }
}

pub fn read(buffer: []u8) types.Error!u8 {
    const result = sys.syscall(.postman, .{
        MODE_READ,
        @intFromPtr(buffer.ptr),
        buffer.len,
    });

    if (result == ERROR_RESULT) {
        return types.Error.ReadFailed;
    }

    return @intCast(result);
}
