//! Manual Guest Check Orchestration

const builtin = @import("builtin");
const std = @import("std");

const image = @import("tests").runner.image;
const limits = @import("tests").constants.runner;
const paths = @import("tests").runner.paths;
const process = @import("tests").runner.process;
const protocol = @import("tests").runner.protocol;
const strings = @import("tests").strings.runner;
const terminal = @import("tests").runner.terminal;
const types = @import("tests").types.host;

const Connection = types.Connection;
const Paths = types.Paths;
const Process = types.Process;

fn imageHash(path: []const u8) ![64]u8 {
    var file = try std.fs.cwd().openFile(path, .{});
    defer file.close();
    var digest = std.crypto.hash.sha2.Sha256.init(.{});
    var buffer: [8192]u8 = undefined;
    while (true) {
        const count = try file.read(&buffer);
        if (count == 0) break;
        digest.update(buffer[0..count]);
    }
    return std.fmt.bytesToHex(digest.finalResult(), .lower);
}

fn connect(allocator: std.mem.Allocator, instance: *Process, port: u16) !Connection {
    var timer = try std.time.Timer.start();
    while (timer.read() < limits.START_NS) {
        if (process.cancelled()) return error.Cancelled;
        if (try process.exited(instance)) return error.GuestExited;
        return protocol.open(allocator, port) catch |failure| switch (failure) {
            error.ConnectionRefused => {
                std.Thread.sleep(limits.POLL_NS);
                continue;
            },
            else => return failure,
        };
    }
    return error.GuestStartTimeout;
}

fn completed(instance: *Process, inputs: *const Paths) !usize {
    var timer = try std.time.Timer.start();
    while (timer.read() < limits.CHECK_NS) {
        if (process.cancelled()) return error.Cancelled;
        if (try process.exited(instance)) return error.GuestExited;
        const bytes = std.fs.cwd().readFileAlloc(std.heap.page_allocator, inputs.Serial, limits.MAX_SERIAL_BYTES) catch |failure| switch (failure) {
            error.FileNotFound => {
                std.Thread.sleep(limits.POLL_NS);
                continue;
            },
            else => return failure,
        };
        defer std.heap.page_allocator.free(bytes);
        if (std.mem.indexOf(u8, bytes, strings.CHECK_FAIL) != null or std.mem.indexOf(u8, bytes, strings.KERNEL_PANIC) != null)
            return error.GuestCheckFailed;
        if (std.mem.indexOf(u8, bytes, strings.READY) != null) {
            if (std.mem.indexOf(u8, bytes, strings.CHECK_BEGIN) == null) return error.MissingGuestChecks;
            const marker = std.mem.indexOf(u8, bytes, strings.CHECK_COMPLETE) orelse return error.IncompleteGuestChecks;
            const number = bytes[marker + strings.CHECK_COMPLETE.len ..];
            const end = std.mem.indexOfAny(u8, number, "\r\n") orelse return error.IncompleteGuestChecks;
            const passed = try std.fmt.parseInt(usize, number[0..end], 10);
            if (passed == 0 or std.mem.count(u8, bytes, strings.CHECK_PASS) != passed) return error.IncompleteGuestChecks;
            return passed;
        }
        std.Thread.sleep(limits.POLL_NS);
    }
    return error.GuestCheckTimeout;
}

pub fn run() !void {
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    const allocator = arena.allocator();
    terminal.begin();
    const inputs = try paths.prepare(allocator);
    var failure: ?anyerror = null;
    var cleanup_error: ?anyerror = null;
    var stage: types.Stage = .Prepare;
    var passed: usize = 0;
    var cleanup_verified = true;
    var hash: [64]u8 = undefined;
    var hashed = false;
    const name = try std.fmt.allocPrint(allocator, strings.NAME_FORMAT, .{std.fs.path.basename(inputs.Run)});
    const address = try std.net.Address.parseIp4(strings.ADDRESS, 0);
    var reservation = try address.listen(.{});
    const port = reservation.listen_address.getPort();
    reservation.deinit();
    const arguments = [_][]const u8{
        inputs.Qemu,                                                                  strings.MACHINE_FLAG, strings.MACHINE,                                                         strings.ACCEL_FLAG,                                                            strings.ACCEL,
        strings.MEMORY_FLAG,                                                          strings.MEMORY,       strings.DRIVE_FLAG,                                                      try std.fmt.allocPrint(allocator, strings.CODE_DRIVE, .{inputs.FirmwareCode}), strings.DRIVE_FLAG,
        try std.fmt.allocPrint(allocator, strings.VARS_DRIVE, .{inputs.Variables}),   strings.DRIVE_FLAG,   try std.fmt.allocPrint(allocator, strings.IMAGE_DRIVE, .{inputs.Image}), strings.SNAPSHOT_FLAG,                                                         strings.SERIAL_FLAG,
        try std.fmt.allocPrint(allocator, strings.SERIAL_ARGUMENT, .{inputs.Serial}), strings.REBOOT_FLAG,  strings.NAME_FLAG,                                                       name,                                                                          strings.QMP_FLAG,
        try std.fmt.allocPrint(allocator, strings.QMP_ARGUMENT, .{port}),             strings.NETWORK_FLAG, strings.NETWORK_NONE,
    };
    var instance = process.init(allocator, &arguments);
    var connection: ?Connection = null;
    var owned = false;
    work: {
        image.prepare(&inputs) catch |reason| {
            failure = reason;
            break :work;
        };
        hash = imageHash(inputs.Image) catch |reason| {
            failure = reason;
            break :work;
        };
        hashed = true;
        stage = .Spawn;
        process.spawn(&instance, &inputs, allocator) catch |reason| {
            failure = reason;
            break :work;
        };
        stage = .Connect;
        connection = connect(std.heap.page_allocator, &instance, port) catch |reason| {
            failure = reason;
            break :work;
        };
        stage = .Verify;
        protocol.verify(std.heap.page_allocator, &connection.?, &inputs, name) catch |reason| {
            failure = reason;
            break :work;
        };
        owned = true;
        stage = .Checks;
        passed = completed(&instance, &inputs) catch |reason| {
            failure = reason;
            break :work;
        };
        stage = .Complete;
    }
    if (owned) {
        protocol.quit(std.heap.page_allocator, &connection.?) catch {};
    }
    process.close(&instance) catch |reason| {
        cleanup_error = reason;
        if (failure == null) stage = .Cleanup;
        cleanup_verified = switch (reason) {
            error.GuestForcedShutdown, error.GuestExitFailed => instance.Reaped,
            else => false,
        };
        if (!cleanup_verified or failure == null) failure = reason;
    };
    if (connection) |socket| socket.Stream.close();
    if (cleanup_verified) {
        std.fs.cwd().deleteFile(inputs.Variables) catch |reason| switch (reason) {
            error.FileNotFound => {},
            else => {
                cleanup_verified = false;
                failure = reason;
            },
        };
    }
    if (hashed) {
        const after = imageHash(inputs.Image) catch null;
        if (after == null or !std.mem.eql(u8, &hash, &after.?)) failure = error.GuestImageChanged;
    }
    const serial = std.fs.cwd().readFileAlloc(allocator, inputs.Serial, limits.MAX_SERIAL_BYTES) catch null;
    if (cleanup_verified) {
        std.fs.cwd().deleteTree(inputs.Run) catch |reason| {
            failure = reason;
            cleanup_error = reason;
            cleanup_verified = false;
            stage = .Cleanup;
        };
    }
    const report: types.Report = .{
        .Status = if (failure == null) strings.PASSED else strings.FAILED,
        .Stage = stage,
        .CleanupError = if (cleanup_error) |reason| @errorName(reason) else null,
        .Platform = @tagName(builtin.os.tag),
        .Passed = passed,
        .Started = instance.Spawned,
        .OriginalProcessReaped = instance.Reaped,
        .CleanupVerified = cleanup_verified,
        .Image = inputs.Image,
        .ImageSHA256 = if (hashed) &hash else "",
        .Serial = inputs.Serial,
        .Error = if (failure) |reason| @errorName(reason) else null,
    };
    terminal.finish(&report, serial);
    if (failure) |reason| return reason;
}
