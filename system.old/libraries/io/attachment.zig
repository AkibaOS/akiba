//! Attachment operations

const sys = @import("sys");
const types = @import("types.zig");

const ERROR_RESULT: u64 = @bitCast(@as(i64, -1));

pub fn attach(location: []const u8, flags: u32) types.Error!types.Descriptor {
    const result = sys.syscall(.attach, .{ @intFromPtr(location.ptr), flags });
    if (result == ERROR_RESULT) {
        return types.Error.NotFound;
    }
    return @truncate(result);
}

pub fn seal(fd: types.Descriptor) void {
    _ = sys.syscall(.seal, .{fd});
}

pub fn viewstack(location: []const u8, entries: []types.StackEntry) types.Error!usize {
    const result = sys.syscall(.viewstack, .{
        @intFromPtr(location.ptr),
        location.len,
        @intFromPtr(entries.ptr),
        entries.len,
    });

    if (result == ERROR_RESULT) {
        return types.Error.InvalidLocation;
    }

    return @intCast(result);
}
