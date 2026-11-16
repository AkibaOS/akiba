//! Portable Owned Guest Process Lifecycle

const builtin = @import("builtin");
const std = @import("std");

const limits = @import("checks").constants.runner;
const posix = @import("checks").runner.posix;
const strings = @import("checks").strings.runner;
const types = @import("checks").types.host;
const windows = @import("checks").runner.windows;

const Paths = types.Paths;
const Process = types.Process;

pub fn init(allocator: std.mem.Allocator, arguments: []const []const u8) Process {
    return .{ .Child = std.process.Child.init(arguments, allocator) };
}

pub fn spawn(instance: *Process, paths: *const Paths, allocator: std.mem.Allocator) !void {
    var environment = try std.process.getEnvMap(allocator);
    defer environment.deinit();
    try environment.put(strings.ENV_TEMP, paths.Run);
    try environment.put(strings.ENV_TMP, paths.Run);
    try environment.put(strings.ENV_TMPDIR, paths.Run);
    instance.Child.env_map = &environment;
    defer instance.Child.env_map = null;
    instance.Child.cwd = paths.Run;
    instance.Child.stdin_behavior = .Ignore;
    instance.Child.stdout_behavior = .Ignore;
    instance.Child.stderr_behavior = .Inherit;
    if (builtin.os.tag == .windows) {
        try windows.install();
        instance.HandlersInstalled = true;
        instance.Job = try windows.create();
        instance.Child.start_suspended = true;
    } else {
        posix.install();
        instance.HandlersInstalled = true;
        instance.Child.pgid = 0;
    }
    try instance.Child.spawn();
    instance.Spawned = true;
    if (builtin.os.tag == .windows) {
        try windows.assign(instance.Job.?, &instance.Child);
        instance.Contained = true;
        try windows.resumeThread(&instance.Child);
    }
}

pub fn cancelled() bool {
    return if (builtin.os.tag == .windows) windows.cancelled() else posix.cancelled();
}

pub fn exited(instance: *Process) !bool {
    if (!instance.Spawned or instance.Reaped or instance.Finished) return true;
    instance.Finished = if (builtin.os.tag == .windows)
        try windows.exited(&instance.Child)
    else
        try posix.exited(&instance.Child);
    return instance.Finished;
}

fn force(instance: *Process) !void {
    if (builtin.os.tag == .windows) {
        if (instance.Contained) {
            try windows.terminate(instance.Job.?);
        } else {
            std.os.windows.TerminateProcess(instance.Child.id, 1) catch |failure| switch (failure) {
                error.AccessDenied => {},
                else => return failure,
            };
        }
    } else {
        try posix.terminateGroup(&instance.Child);
    }
}

pub fn close(instance: *Process) !void {
    defer {
        if (builtin.os.tag == .windows) {
            if (instance.Job) |job| windows.close(job);
            instance.Job = null;
            if (instance.HandlersInstalled) windows.restore();
            instance.HandlersInstalled = false;
        } else if (instance.HandlersInstalled) {
            posix.restore();
            instance.HandlersInstalled = false;
        }
    }
    if (!instance.Spawned or instance.Reaped) return;
    var timer = try std.time.Timer.start();
    while (!try exited(instance) and timer.read() < limits.QUIT_NS) std.Thread.sleep(limits.POLL_NS);
    const forced = !instance.Finished;
    if (forced) {
        try force(instance);
        timer.reset();
        while (!try exited(instance) and timer.read() < limits.QUIT_NS) std.Thread.sleep(limits.POLL_NS);
        if (!instance.Finished) return error.GuestCleanupFailed;
    }
    if (builtin.os.tag != .windows) try posix.terminateGroup(&instance.Child);
    const child_id = instance.Child.id;
    instance.Term = instance.Child.wait() catch |failure| {
        if (builtin.os.tag != .windows) {
            _ = std.posix.waitpid(child_id, 0);
            instance.Reaped = true;
        }
        return failure;
    };
    instance.Reaped = true;
    if (builtin.os.tag == .windows) {
        timer.reset();
        while (!try windows.empty(instance.Job.?) and timer.read() < limits.QUIT_NS) std.Thread.sleep(limits.POLL_NS);
        if (!try windows.empty(instance.Job.?)) return error.GuestCleanupFailed;
    } else {
        timer.reset();
        while (!try posix.groupGone(child_id) and timer.read() < limits.QUIT_NS) std.Thread.sleep(limits.POLL_NS);
        if (!try posix.groupGone(child_id)) return error.GuestCleanupFailed;
    }
    if (forced) return error.GuestForcedShutdown;
    const term = instance.Term.?;
    if (term != .Exited or term.Exited != 0) return error.GuestExitFailed;
}
