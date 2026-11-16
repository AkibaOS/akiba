//! Actual Loopback QMP Client Regressions

const builtin = @import("builtin");
const std = @import("std");

const inputs = @import("tests").constants.protocol;
const protocol = @import("tests").runner.protocol;
const socket = @import("tests").runner.socket;
const strings = @import("tests").strings.protocol;
const types = @import("tests").types.protocol;

pub fn rejects(scenario: types.Scenario, expected: anyerror) !void {
    try exercise(scenario, expected);
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
    if (protocol.open(std.testing.allocator, server.listen_address.getPort())) |connection| {
        connection.Stream.close();
        if (connection.Sequence != 1) actual = error.UnexpectedSequence;
    } else |failure| actual = failure;
    worker.join();
    if (state.Failure) |failure| return failure;
    try std.testing.expectEqual(expected, actual);
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
        .ErrorReply, .Events => {},
    }
    try send(handle, strings.GREETING);
    var request: [inputs.REQUEST_BYTES]u8 = undefined;
    const length = try line(handle, &request);
    try std.testing.expect(std.mem.indexOf(u8, request[0..length], strings.CAPABILITIES) != null);
    if (state.Scenario == .ErrorReply) return send(handle, strings.ERROR);
    try send(handle, strings.EVENT ++ strings.WRONG_ID ++ strings.REPLY);
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
