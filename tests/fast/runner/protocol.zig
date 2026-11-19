//! Actual Loopback QMP Client Regressions

const builtin = @import("builtin");
const std = @import("std");

const fixtures = @import("tests").strings.oracle;
const inputs = @import("tests").constants.protocol;
const protocol = @import("tests").runner.protocol;
const runner = @import("tests").runner;
const socket = @import("tests").runner.socket;
const strings = @import("tests").strings.protocol;
const types = @import("tests").types.protocol;
const Connection = @import("tests").types.host.Connection;

pub fn rejects(scenario: types.Scenario, expected: anyerror) !void {
    try exercise(scenario, expected);
}

pub fn accepts(scenario: types.Scenario) !void {
    try exercise(scenario, null);
}

pub fn events() !void {
    try exercise(.Events, null);
}

pub fn deadline() !void {
    var timer = try std.time.Timer.start();
    try exercise(.SlowGreeting, error.QmpOperationTimeout);
    const elapsed = timer.read();
    try std.testing.expect(elapsed >= inputs.MIN_DEADLINE_NS and elapsed <= inputs.MAX_DEADLINE_NS);
}

fn exercise(scenario: types.Scenario, expected: ?anyerror) !void {
    const address = try std.net.Address.parseIp4(strings.ADDRESS, 0);
    var server = try address.listen(.{});
    defer server.deinit();
    var state: types.Peer = .{ .Server = &server, .Scenario = scenario };
    const worker = try std.Thread.spawn(.{}, peer, .{&state});
    var actual: ?anyerror = null;
    if (protocol.open(std.testing.allocator, server.listen_address.getPort())) |opened| {
        var connection = opened;
        defer connection.Stream.close();
        if (connection.Sequence != 1) actual = error.UnexpectedSequence;
        command(&connection, scenario) catch |failure| {
            actual = failure;
        };
    } else |failure| actual = failure;
    worker.join();
    if (state.Failure) |failure| return failure;
    try std.testing.expectEqual(expected, actual);
}

fn command(connection: *Connection, scenario: types.Scenario) !void {
    switch (scenario) {
        .WrongName => try protocol.verifyName(std.testing.allocator, connection, strings.EXPECTED_NAME),
        .QuitClosed, .QuitRefused => try protocol.quit(std.testing.allocator, connection),
        .LateReply => try protocol.action(std.testing.allocator, connection, strings.QUERY_JOBS, null),
        .Headless => try protocol.verifyWindow(std.testing.allocator, connection),
        .OperatorClosed, .OperatorQuit, .ResetToShutdown, .OrdinaryPanic => try ordinary(connection, scenario == .OrdinaryPanic),
        .RecoverRunning, .RecoverPaused, .RecoverReset => try runner.recovery.quiesce(std.testing.allocator, connection),
        else => {},
    }
}

fn ordinary(connection: *Connection, panic_after_ready: bool) !void {
    var directory = std.testing.tmpDir(.{});
    defer directory.cleanup();
    const file = try directory.dir.createFile(fixtures.SERIAL_FILE, .{ .read = true });
    defer file.close();
    try file.writeAll(fixtures.MISSING);
    if (panic_after_ready) try file.writeAll(fixtures.PANIC);
    try protocol.superviseOrdinary(std.testing.allocator, connection, .{ .File = &file, .Start = 0 });
}

fn peer(state: *types.Peer) void {
    serve(state) catch |failure| {
        state.Failure = failure;
    };
}

fn serve(state: *types.Peer) !void {
    const accepted = try state.Server.accept();
    defer accepted.stream.close();
    const handle = accepted.stream.handle;
    if (builtin.os.tag == .windows) {
        const timeout = inputs.TIMEOUT_MS;
        try std.posix.setsockopt(handle, std.posix.SOL.SOCKET, std.posix.SO.RCVTIMEO, std.mem.asBytes(&timeout));
        try std.posix.setsockopt(handle, std.posix.SOL.SOCKET, std.posix.SO.SNDTIMEO, std.mem.asBytes(&timeout));
    } else {
        const timeout: std.posix.timeval = .{ .sec = inputs.TIMEOUT_SECONDS, .usec = 0 };
        try std.posix.setsockopt(handle, std.posix.SOL.SOCKET, std.posix.SO.RCVTIMEO, std.mem.asBytes(&timeout));
        try std.posix.setsockopt(handle, std.posix.SOL.SOCKET, std.posix.SO.SNDTIMEO, std.mem.asBytes(&timeout));
    }
    switch (state.Scenario) {
        .Disconnect => return,
        .InvalidGreeting => return send(handle, strings.INVALID_GREETING),
        .SlowGreeting => {
            try send(handle, strings.SLOW_BEGIN);
            for (0..inputs.SLOW_BYTES) |_| {
                std.Thread.sleep(inputs.BYTE_INTERVAL_NS);
                send(handle, strings.SLOW_BYTE) catch return;
            }
            return;
        },
        else => {},
    }
    try send(handle, strings.GREETING);
    var request: [inputs.REQUEST_BYTES]u8 = undefined;
    const length = try line(handle, &request);
    try std.testing.expect(std.mem.indexOf(u8, request[0..length], strings.CAPABILITIES) != null);
    if (state.Scenario == .ErrorReply) return send(handle, strings.ERROR);
    if (state.Scenario == .Reset) return send(handle, strings.TERMINAL_EVENT ++ strings.REPLY);
    if (state.Scenario == .WrongName) {
        try send(handle, strings.REPLY);
        const query_length = try line(handle, &request);
        try std.testing.expect(std.mem.indexOf(u8, request[0..query_length], strings.QUERY_NAME) != null);
        return send(handle, strings.WRONG_NAME);
    }
    switch (state.Scenario) {
        .QuitClosed, .QuitRefused => {
            try send(handle, strings.REPLY);
            const quit_length = try line(handle, &request);
            try std.testing.expect(std.mem.indexOf(u8, request[0..quit_length], strings.QUIT) != null);
            if (state.Scenario == .QuitRefused) return send(handle, strings.QUIT_REFUSED);
        },
        .LateReply => {
            try send(handle, strings.REPLY);
            const query_length = try line(handle, &request);
            try std.testing.expect(std.mem.indexOf(u8, request[0..query_length], strings.QUERY_JOBS) != null);
            try send(handle, strings.JOB_REPLY_START);
            std.Thread.sleep(inputs.LATE_REPLY_NS);
            send(handle, strings.JOB_REPLY_END) catch {};
        },
        .Headless => {
            try send(handle, strings.REPLY);
            const query_length = line(handle, &request) catch |failure| switch (failure) {
                error.DisconnectedPeer => return,
                else => return failure,
            };
            try std.testing.expect(std.mem.indexOf(u8, request[0..query_length], strings.QUERY_DISPLAY) != null);
            try send(handle, strings.HEADLESS_REPLY);
        },
        .OperatorClosed, .OrdinaryPanic => try send(handle, strings.REPLY ++ strings.OPERATOR_CLOSED),
        .OperatorQuit => try send(handle, strings.REPLY ++ strings.OPERATOR_QUIT),
        .ResetToShutdown => try send(handle, strings.REPLY ++ strings.RESET_TO_SHUTDOWN),
        .RecoverRunning, .RecoverPaused, .RecoverReset => try recoveryPeer(handle, state.Scenario, &request),
        else => try send(handle, strings.EVENT ++ strings.WRONG_ID ++ strings.REPLY),
    }
}

fn recoveryPeer(handle: std.net.Stream.Handle, scenario: types.Scenario, request: []u8) !void {
    try send(handle, strings.REPLY);
    const query_length = line(handle, request) catch |failure| switch (failure) {
        error.DisconnectedPeer => return,
        else => return failure,
    };
    try std.testing.expect(std.mem.indexOf(u8, request[0..query_length], strings.QUERY_STATUS) != null);
    if (scenario == .RecoverReset) return send(handle, strings.TERMINAL_EVENT ++ strings.RECOVERY_RUNNING);
    if (scenario == .RecoverPaused) return send(handle, strings.RECOVERY_ALREADY_PAUSED);
    try send(handle, strings.RECOVERY_RUNNING);
    const stop_length = try line(handle, request);
    try std.testing.expect(std.mem.indexOf(u8, request[0..stop_length], strings.STOP) != null);
    try send(handle, strings.RECOVERY_STOPPED);
    const paused_length = try line(handle, request);
    try std.testing.expect(std.mem.indexOf(u8, request[0..paused_length], strings.QUERY_STATUS) != null);
    try send(handle, strings.RECOVERY_PAUSED);
}

fn send(handle: std.net.Stream.Handle, bytes: []const u8) !void {
    var offset: usize = 0;
    while (offset < bytes.len) {
        const count = try socket.send(handle, bytes[offset..]);
        if (count == 0) return error.DisconnectedPeer;
        offset += count;
    }
}

fn line(handle: std.net.Stream.Handle, destination: []u8) !usize {
    for (destination, 0..) |*byte, index| {
        if (try socket.receive(handle, @as(*[1]u8, @ptrCast(byte))) == 0) return error.DisconnectedPeer;
        if (byte.* == '\n') return index + 1;
    }
    return error.RequestTooLarge;
}
