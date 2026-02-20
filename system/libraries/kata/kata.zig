//! Kata (process) control

const sys = @import("sys");

const ERROR_RESULT: u64 = @bitCast(@as(i64, -1));

pub const Error = error{
    SpawnFailed,
    WaitFailed,
};

pub fn yield() void {
    _ = sys.syscall(.yield, .{});
}

pub fn exit(code: u64) noreturn {
    _ = sys.syscall(.exit, .{code});
    unreachable;
}

pub fn spawn(location: []const u8) Error!u32 {
    const result = sys.syscall(.spawn, .{ @intFromPtr(location.ptr), location.len, @as(u64, 0), @as(u64, 0) });
    if (result == ERROR_RESULT) {
        return Error.SpawnFailed;
    }
    return @truncate(result);
}

pub fn spawnWithParams(location: []const u8, params: [][*:0]const u8) Error!u32 {
    const result = sys.syscall(.spawn, .{ @intFromPtr(location.ptr), location.len, @intFromPtr(params.ptr), params.len });
    if (result == ERROR_RESULT) {
        return Error.SpawnFailed;
    }
    return @truncate(result);
}

pub fn wait(pid: u32) Error!u64 {
    while (true) {
        const result = sys.syscall(.wait, .{pid});
        if (result != ERROR_RESULT) {
            return result;
        }
        yield();
    }
}
