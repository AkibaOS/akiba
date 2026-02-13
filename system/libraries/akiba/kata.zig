//! Kata (process) control functions

const sys = @import("sys.zig");

pub fn yield() void {
    _ = sys.syscall(.yield, .{});
}

pub fn exit(code: u64) noreturn {
    _ = sys.syscall(.exit, .{code});
    unreachable;
}

pub fn spawn(path: []const u8) !u32 {
    const result = sys.syscall(.spawn, .{ @intFromPtr(path.ptr), path.len });
    if (result == @as(u64, @bitCast(@as(i64, -1)))) {
        return error.SpawnFailed;
    }
    return @truncate(result);
}

pub fn spawn_with_args(path: []const u8, argv: []const [*:0]const u8) !u32 {
    const result = sys.spawn_with_args(path, argv);
    if (result == @as(u64, @bitCast(@as(i64, -1)))) {
        return error.SpawnFailed;
    }
    return @truncate(result);
}

pub fn wait(pid: u32) !u64 {
    // Retry loop: keep checking until the target exits
    while (true) {
        const result = sys.syscall(.wait, .{pid});
        if (result != @as(u64, @bitCast(@as(i64, -1)))) {
            return result;
        }
        // Target still running, yield and try again
        yield();
    }
}
