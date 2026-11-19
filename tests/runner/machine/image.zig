//! Disposable Checkpoint Storage And Immutable Input Fingerprints

const std = @import("std");

const limits = @import("tests").runner.constants.limits;
const process = @import("tests").runner.process.lifetime;
const strings = @import("tests").runner.strings.runner;
const types = @import("tests").runner.types.host;

pub fn fingerprint(path: []const u8) !types.Fingerprint {
    var file = try std.fs.cwd().openFile(path, .{});
    defer file.close();
    const before = try file.stat();
    var digest = std.crypto.hash.sha2.Sha256.init(.{});
    var buffer: [8192]u8 = undefined;
    while (true) {
        const count = try file.read(&buffer);
        if (count == 0) break;
        digest.update(buffer[0..count]);
    }
    const after = try file.stat();
    if (before.size != after.size or before.mtime != after.mtime) return error.GuestImageChanged;
    return .{ .Size = before.size, .Modified = before.mtime, .Digest = digest.finalResult() };
}

pub fn prepare(allocator: std.mem.Allocator, paths: *const types.Paths, cleaned: *bool) !void {
    try create(allocator, paths, &.{ paths.QemuImage, strings.CREATE, strings.FORMAT_FLAG, strings.QCOW2, strings.BACKING_FORMAT_FLAG, strings.RAW, strings.BACKING_FLAG, paths.FirmwareTemplate, paths.Variables }, cleaned);
    try create(allocator, paths, &.{ paths.QemuImage, strings.CREATE, strings.FORMAT_FLAG, strings.QCOW2, paths.State, strings.STATE_SIZE }, cleaned);
}

fn create(allocator: std.mem.Allocator, paths: *const types.Paths, arguments: []const []const u8, cleaned: *bool) !void {
    var tool = process.init(allocator, arguments);
    const result = runTool(allocator, paths, &tool);
    process.close(&tool) catch |failure| {
        cleaned.* = tool.Reaped and (failure == error.GuestForcedShutdown or failure == error.GuestExitFailed);
        std.log.err(strings.STATE_TOOL_FAILURE, .{@errorName(failure)});
        return error.CheckpointImageCreationFailed;
    };
    try result;
}

fn runTool(allocator: std.mem.Allocator, paths: *const types.Paths, tool: *types.Process) !void {
    try process.spawn(tool, paths, allocator);
    var timer = try std.time.Timer.start();
    while (!try process.exited(tool)) {
        if (process.cancelled()) return error.Cancelled;
        if (timer.read() >= limits.START_NS) return error.CheckpointImageTimeout;
        std.Thread.sleep(limits.POLL_NS);
    }
    if (process.cancelled()) return error.Cancelled;
}
