//! Manual Guest Check Orchestration

const builtin = @import("builtin");
const std = @import("std");

const driverlabels = @import("tests").strings.drivers;
const image = @import("tests").runner.image;
const limits = @import("tests").constants.runner;
const paths = @import("tests").runner.paths;
const phase = @import("tests").runner.phase;
const process = @import("tests").runner.process;
const protocol = @import("tests").runner.protocol;
const result = @import("tests").runner.result;
const scenario = @import("tests").strings.scenario;
const screen = @import("tests").screen;
const strings = @import("tests").strings.runner;
const terminal = @import("tests").runner.terminal;
const types = @import("tests").types.host;

const Connection = types.Connection;
const Paths = types.Paths;
const Process = types.Process;
const Scenario = @import("tests").types.scenario.Scenario;

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

fn completed(instance: *Process, inputs: *const Paths, connection: *Connection, selected: Scenario, timer: *std.time.Timer) !usize {
    var input_sent = false;
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
        if (selected == .Devices and !input_sent and std.mem.indexOf(u8, bytes, driverlabels.READY) != null) {
            try protocol.pressKey(std.heap.page_allocator, connection);
            input_sent = true;
        }
        if (try result.evaluate(bytes, selected)) |passed| {
            if (selected == .Devices and !input_sent) return error.MissingInjectedInput;
            return passed;
        }
        std.Thread.sleep(limits.POLL_NS);
    }
    return error.GuestCheckTimeout;
}

pub fn run() !void {
    for (std.enums.values(Scenario)) |selected| try runScenario(selected);
}

fn buildDateArgument(allocator: std.mem.Allocator, path: []const u8) ?[]const u8 {
    const image_stat = std.fs.cwd().statFile(path) catch return null;
    var buffer: [screen.constants.frame.DATE_BYTES]u8 = undefined;
    const date = screen.date.format(&buffer, image_stat.mtime) orelse return null;
    return std.fmt.allocPrint(allocator, scenario.BUILD_DATE_ARGUMENT, .{date}) catch null;
}

fn startPhase(allocator: std.mem.Allocator, instance: *Process, connection: *Connection, timer: *std.time.Timer, port: u16, serial: []const u8, selected: Scenario) !void {
    try protocol.verifyPhasePort(allocator, connection, port);
    const stream = try phase.open(port, instance, timer);
    defer stream.close();
    const running = try protocol.command(allocator, connection, strings.CONTINUE);
    running.deinit();
    try phase.select(stream, instance, timer, serial, .{ .Epoch = @max(1, std.crypto.random.int(u64)), .Scenario = selected });
}

fn runScenario(selected: Scenario) !void {
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    const allocator = arena.allocator();
    terminal.begin();
    const inputs = try paths.prepare(allocator, selected);
    var failure: ?anyerror = null;
    var cleanup_error: ?anyerror = null;
    var stage: types.Stage = .Prepare;
    var passed: usize = 0;
    var cleanup_verified = true;
    var hash: [64]u8 = undefined;
    var hashed = false;
    const name = try std.fmt.allocPrint(allocator, strings.NAME_FORMAT, .{std.fs.path.basename(inputs.Run)});
    const endpoints = reserve: {
        const address = try std.net.Address.parseIp4(strings.ADDRESS, 0);
        var monitor_reservation = try address.listen(.{});
        defer monitor_reservation.deinit();
        var phase_reservation = if (selected != .Firmware) try address.listen(.{}) else null;
        defer if (phase_reservation) |*server| server.deinit();
        break :reserve .{
            .Qmp = monitor_reservation.listen_address.getPort(),
            .Phase = if (phase_reservation) |server| @as(?u16, server.listen_address.getPort()) else null,
        };
    };
    const standard_arguments = [_][]const u8{
        inputs.Qemu,                                                                  strings.MACHINE_FLAG, strings.MACHINE,                                                         strings.ACCEL_FLAG,                                                            strings.ACCEL,
        strings.MEMORY_FLAG,                                                          strings.MEMORY,       strings.DRIVE_FLAG,                                                      try std.fmt.allocPrint(allocator, strings.CODE_DRIVE, .{inputs.FirmwareCode}), strings.DRIVE_FLAG,
        try std.fmt.allocPrint(allocator, strings.VARS_DRIVE, .{inputs.Variables}),   strings.DRIVE_FLAG,   try std.fmt.allocPrint(allocator, strings.IMAGE_DRIVE, .{inputs.Image}), strings.SNAPSHOT_FLAG,                                                         strings.SERIAL_FLAG,
        try std.fmt.allocPrint(allocator, strings.SERIAL_ARGUMENT, .{inputs.Serial}), strings.REBOOT_FLAG,  strings.NAME_FLAG,                                                       name,                                                                          strings.QMP_FLAG,
        try std.fmt.allocPrint(allocator, strings.QMP_ARGUMENT, .{endpoints.Qmp}),    strings.NETWORK_FLAG, strings.NETWORK_NONE,
    };
    var arguments: std.ArrayList([]const u8) = .empty;
    try arguments.appendSlice(allocator, &standard_arguments);
    if (endpoints.Phase) |port| {
        const endpoint = try std.fmt.allocPrint(allocator, strings.PHASE_SOCKET, .{port});
        try arguments.appendSlice(allocator, &.{
            strings.PAUSE_AT_START_FLAG, strings.CHARDEV_FLAG, endpoint,
            strings.SERIAL_FLAG,         strings.PHASE_SERIAL, scenario.FLAG,
            scenario.PHASE_ARGUMENT,
        });
    } else {
        const firmware = try std.fmt.allocPrint(allocator, scenario.ARGUMENT, .{@tagName(selected)});
        try arguments.appendSlice(allocator, &.{ scenario.FLAG, firmware });
    }
    if (selected == .Standard) {
        if (buildDateArgument(allocator, inputs.Image)) |date| try arguments.appendSlice(allocator, &.{ scenario.FLAG, date });
    }
    if (selected == .Devices) try arguments.appendSlice(allocator, &.{ strings.DISPLAY_FLAG, strings.DISPLAY_NONE });
    var instance = process.init(allocator, arguments.items);
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
        connection = connect(std.heap.page_allocator, &instance, endpoints.Qmp) catch |reason| {
            failure = reason;
            break :work;
        };
        stage = .Verify;
        const verified = if (endpoints.Phase != null)
            protocol.verifyPaused(allocator, &connection.?, &inputs, name)
        else
            protocol.verify(allocator, &connection.?, &inputs, name);
        verified catch |reason| {
            failure = reason;
            break :work;
        };
        owned = true;
        var timer = std.time.Timer.start() catch |reason| {
            failure = reason;
            break :work;
        };
        if (endpoints.Phase) |port| {
            stage = .Select;
            startPhase(allocator, &instance, &connection.?, &timer, port, inputs.Serial, selected) catch |reason| {
                failure = reason;
                break :work;
            };
        }
        stage = .Checks;
        passed = completed(&instance, &inputs, &connection.?, selected, &timer) catch |reason| {
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
    if (connection) |control| control.Stream.close();
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
        .Scenario = selected,
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
