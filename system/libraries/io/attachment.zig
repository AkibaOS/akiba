//! Attachment operations

const sys = @import("sys");
const types = @import("types.zig");

const ERROR_RESULT: u64 = @bitCast(@as(i64, -1));

pub fn attach(path: []const u8, flags: u32) types.Error!types.FileDescriptor {
    const result = sys.syscall(.attach, .{ @intFromPtr(path.ptr), flags });
    if (result == ERROR_RESULT) {
        return types.Error.NotFound;
    }
    return @truncate(result);
}

pub fn seal(fd: types.FileDescriptor) void {
    _ = sys.syscall(.seal, .{fd});
}

pub fn viewstack(path: []const u8, entries: []types.StackEntry) types.Error!usize {
    const result = sys.syscall(.viewstack, .{
        @intFromPtr(path.ptr),
        path.len,
        @intFromPtr(entries.ptr),
        entries.len,
    });

    if (result == ERROR_RESULT) {
        return types.Error.InvalidPath;
    }

    return @intCast(result);
}
