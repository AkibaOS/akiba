//! POSIX Owned Process Group Control

const builtin = @import("builtin");
const std = @import("std");

const limits = @import("tests").constants.runner;

var interrupted: std.atomic.Value(bool) = .init(false);
var previous_interrupt: std.posix.Sigaction = undefined;
var previous_terminate: std.posix.Sigaction = undefined;

extern "c" fn waitid(c_uint, c_uint, *std.c.siginfo_t, c_int) c_int;

fn onSignal(_: c_int) callconv(.c) void {
    interrupted.store(true, .monotonic);
}

pub fn install() void {
    interrupted.store(false, .monotonic);
    const action: std.posix.Sigaction = .{
        .handler = .{ .handler = onSignal },
        .mask = std.mem.zeroes(std.posix.sigset_t),
        .flags = 0,
    };
    std.posix.sigaction(std.posix.SIG.INT, &action, &previous_interrupt);
    std.posix.sigaction(std.posix.SIG.TERM, &action, &previous_terminate);
}

pub fn restore() void {
    std.posix.sigaction(std.posix.SIG.INT, &previous_interrupt, null);
    std.posix.sigaction(std.posix.SIG.TERM, &previous_terminate, null);
}

pub fn cancelled() bool {
    return interrupted.load(.monotonic);
}

pub fn exited(child: *const std.process.Child) !bool {
    var information: std.c.siginfo_t = undefined;
    @memset(std.mem.asBytes(&information), 0);
    const flags: c_int = if (builtin.os.tag == .macos)
        limits.DARWIN_WAIT_EXITED | limits.DARWIN_WAIT_NOWAIT | std.posix.W.NOHANG
    else
        @intCast(std.posix.W.EXITED | std.posix.W.NOWAIT | std.posix.W.NOHANG);
    while (true) {
        const result = waitid(limits.WAIT_ID_PID, @intCast(child.id), &information, flags);
        switch (std.posix.errno(result)) {
            .SUCCESS => return information.signo != 0,
            .INTR => continue,
            else => return error.ProcessWaitFailed,
        }
    }
}

pub fn groupGone(id: std.posix.pid_t) !bool {
    std.posix.kill(-id, 0) catch |failure| switch (failure) {
        error.ProcessNotFound => return true,
        else => return failure,
    };
    return false;
}

pub fn terminateGroup(child: *const std.process.Child) !void {
    std.posix.kill(-child.id, std.posix.SIG.KILL) catch |failure| switch (failure) {
        error.ProcessNotFound => {},
        else => return failure,
    };
}
