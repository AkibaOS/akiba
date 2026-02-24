//! Stream operations

const kata = @import("kata");
const sys = @import("sys");
const types = @import("types.zig");

const ERROR_RESULT: u64 = @bitCast(@as(i64, -1));
const EAGAIN_RESULT: u64 = @bitCast(@as(i64, -2));

pub fn view(fd: types.Descriptor, buffer: []u8) types.Error!usize {
    const result = sys.syscall(.view, .{ fd, @intFromPtr(buffer.ptr), buffer.len });
    if (result == ERROR_RESULT) {
        return types.Error.ReadFailed;
    }
    return result;
}

pub fn mark(fd: types.Descriptor, data: []const u8, color: u32) types.Error!usize {
    const result = sys.syscall(.mark, .{ fd, @intFromPtr(data.ptr), data.len, color });
    if (result == ERROR_RESULT) {
        return types.Error.WriteFailed;
    }
    return result;
}

pub fn getchar() types.Error!u8 {
    while (true) {
        const result = sys.syscall(.getkeychar, .{});
        if (result != EAGAIN_RESULT) {
            if (result != ERROR_RESULT) {
                return @truncate(result);
            }
            return types.Error.ReadFailed;
        }
        kata.yield();
    }
}

pub fn wipe() void {
    _ = sys.syscall(.wipe, .{});
}
