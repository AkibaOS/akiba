//! Bounded Owned Guest QMP Protocol

const builtin = @import("builtin");
const std = @import("std");

const limits = @import("tests").runner.constants.limits;
const paths = @import("tests").runner.machine.paths;
const process = @import("tests").runner.process.lifetime;
const serial = @import("tests").runner.transport.serial;
const socket = @import("tests").runner.transport.socket;
const strings = @import("tests").runner.strings.runner;
const types = @import("tests").runner.types.host;
const verdict = @import("tests").runner.report.result;

const Connection = types.Connection;
const Deadline = types.Deadline;
const Value = std.json.Value;

fn remaining(deadline: Deadline, ignore_cancel: bool) !u64 {
    if (!ignore_cancel and process.cancelled()) return error.Cancelled;
    const elapsed = deadline.Timer.read();
    if (elapsed >= deadline.Limit) return error.QmpOperationTimeout;
    return deadline.Limit - elapsed;
}

fn readLine(allocator: std.mem.Allocator, connection: *Connection, deadline: Deadline, ignore_cancel: bool) ![]u8 {
    var bytes: std.ArrayList(u8) = .empty;
    errdefer bytes.deinit(allocator);
    var ready = [_]std.posix.pollfd{.{ .fd = connection.Stream.handle, .events = std.posix.POLL.IN, .revents = 0 }};
    while (bytes.items.len < limits.MAX_PACKET_BYTES) {
        const interval = @min(try remaining(deadline, ignore_cancel), limits.POLL_NS);
        if (try std.posix.poll(&ready, @intCast(interval / std.time.ns_per_ms)) == 0) continue;
        _ = try remaining(deadline, ignore_cancel);
        var next: [1]u8 = undefined;
        if (try socket.receive(connection.Stream.handle, &next) == 0) return error.QmpDisconnected;
        if (next[0] == '\n') return bytes.toOwnedSlice(allocator);
        try bytes.append(allocator, next[0]);
    }
    return error.QmpPacketTooLarge;
}

pub fn open(allocator: std.mem.Allocator, port: u16) !Connection {
    const stream = try socket.open(port);
    errdefer stream.close();
    var connection: Connection = .{ .Stream = stream };
    var timer = try std.time.Timer.start();
    const greeting = try readLine(allocator, &connection, .{ .Timer = &timer, .Limit = limits.PROTOCOL_NS }, false);
    defer allocator.free(greeting);
    const parsed = try std.json.parseFromSlice(Value, allocator, greeting, .{});
    defer parsed.deinit();
    if (field(parsed.value, strings.QMP_MEMBER) == null) return error.QmpInvalidGreeting;
    try action(allocator, &connection, strings.CAPABILITIES, null);
    return connection;
}

pub fn command(allocator: std.mem.Allocator, connection: *Connection, name: []const u8, arguments: ?[]const u8) !std.json.Parsed(Value) {
    var timer = try std.time.Timer.start();
    return commandWithin(allocator, connection, name, arguments, .{ .Timer = &timer, .Limit = limits.PROTOCOL_NS });
}

pub fn commandWithin(allocator: std.mem.Allocator, connection: *Connection, name: []const u8, arguments: ?[]const u8, deadline: Deadline) !std.json.Parsed(Value) {
    return sendRequest(allocator, connection, name, arguments, deadline, false);
}

pub fn action(allocator: std.mem.Allocator, connection: *Connection, name: []const u8, arguments: ?[]const u8) !void {
    const response = try command(allocator, connection, name, arguments);
    response.deinit();
}

pub fn quit(allocator: std.mem.Allocator, connection: *Connection) !void {
    var timer = try std.time.Timer.start();
    const response = sendRequest(allocator, connection, strings.QUIT, null, .{ .Timer = &timer, .Limit = limits.PROTOCOL_NS }, true) catch |failure| switch (failure) {
        error.QmpQuitReplyOmitted => return,
        else => return failure,
    };
    response.deinit();
}

pub fn superviseOrdinary(allocator: std.mem.Allocator, connection: *Connection, evidence: types.Epoch) !void {
    var pending = [_]std.posix.pollfd{.{ .fd = connection.Stream.handle, .events = std.posix.POLL.IN, .revents = 0 }};
    while (true) {
        if (process.cancelled()) return error.Cancelled;
        try checkOrdinary(allocator, evidence);
        if (try std.posix.poll(&pending, limits.ORDINARY_POLL_MS) == 0) continue;
        var timer = try std.time.Timer.start();
        const line = try readLine(allocator, connection, .{ .Timer = &timer, .Limit = limits.PROTOCOL_NS }, false);
        defer allocator.free(line);
        const parsed = try std.json.parseFromSlice(Value, allocator, line, .{});
        defer parsed.deinit();
        if (equal(parsed.value, strings.EVENT, strings.SHUTDOWN)) {
            const data = field(parsed.value, strings.EVENT_DATA) orelse return error.UnexpectedGuestEvent;
            const host_closed = boolean(data, strings.GUEST_ORIGIN, false) and
                (equal(data, strings.REASON, strings.HOST_WINDOW_CLOSE) or equal(data, strings.REASON, strings.HOST_QUIT));
            const guest_shutdown = boolean(data, strings.GUEST_ORIGIN, true) and equal(data, strings.REASON, strings.GUEST_SHUTDOWN);
            if (host_closed or guest_shutdown) {
                try checkOrdinary(allocator, evidence);
                return;
            }
        }
        if (terminalEvent(parsed.value, false)) {
            if (!builtin.is_test) std.debug.print(strings.ORDINARY_EVENT, .{line});
            return error.UnexpectedGuestEvent;
        }
    }
}

fn checkOrdinary(allocator: std.mem.Allocator, evidence: types.Epoch) !void {
    const bytes = try serial.read(allocator, evidence);
    defer allocator.free(bytes);
    if (!try verdict.ordinaryReady(bytes)) return error.OrdinaryEvidenceLost;
}

pub fn pressKey(allocator: std.mem.Allocator, connection: *Connection, key: []const u8) !void {
    const arguments = try std.fmt.allocPrint(allocator, strings.KEY_ARGUMENTS, .{key});
    defer allocator.free(arguments);
    try action(allocator, connection, strings.SEND_KEY, arguments);
}

fn terminalEvent(message: Value, closing: bool) bool {
    const event = text(message, strings.EVENT) orelse return false;
    if (std.mem.eql(u8, event, strings.SHUTDOWN)) {
        const data = field(message, strings.EVENT_DATA) orelse return true;
        return !closing or !equal(data, strings.REASON, strings.HOST_QUIT);
    }
    return std.mem.eql(u8, event, strings.RESET) or
        std.mem.eql(u8, event, strings.POWERDOWN) or
        std.mem.eql(u8, event, strings.GUEST_PANICKED) or
        std.mem.eql(u8, event, strings.GUEST_CRASHLOADED);
}

fn sendRequest(allocator: std.mem.Allocator, connection: *Connection, name: []const u8, arguments: ?[]const u8, deadline: Deadline, closing: bool) !std.json.Parsed(Value) {
    connection.Sequence += 1;
    const request = if (arguments) |values|
        try std.fmt.allocPrint(allocator, strings.QMP_ARGUMENT_REQUEST, .{ name, values, connection.Sequence })
    else
        try std.fmt.allocPrint(allocator, strings.QMP_REQUEST, .{ name, connection.Sequence });
    defer allocator.free(request);
    var sent: usize = 0;
    while (sent < request.len) {
        _ = try remaining(deadline, closing);
        const count = try socket.send(connection.Stream.handle, request[sent..]);
        if (count == 0) return error.QmpDisconnected;
        sent += count;
    }
    for (0..limits.MAX_PACKETS) |_| {
        const line = readLine(allocator, connection, deadline, closing) catch |failure| switch (failure) {
            error.QmpDisconnected, error.ConnectionResetByPeer => if (closing) return error.QmpQuitReplyOmitted else return failure,
            else => return failure,
        };
        defer allocator.free(line);
        const parsed = try std.json.parseFromSlice(Value, allocator, line, .{ .allocate = .alloc_always });
        if (terminalEvent(parsed.value, closing)) {
            parsed.deinit();
            return error.UnexpectedGuestEvent;
        }
        const id = field(parsed.value, strings.QMP_ID);
        if (id == null or id.? != .integer or id.?.integer < 0 or @as(u64, @intCast(id.?.integer)) != connection.Sequence) {
            parsed.deinit();
            continue;
        }
        if (field(parsed.value, strings.QMP_ERROR) != null or field(parsed.value, strings.QMP_RETURN) == null) {
            parsed.deinit();
            return error.QmpCommandFailed;
        }
        return parsed;
    }
    return error.QmpEventLimit;
}

pub fn field(value: Value, name: []const u8) ?Value {
    return if (value == .object) value.object.get(name) else null;
}

pub fn text(value: Value, name: []const u8) ?[]const u8 {
    const member = field(value, name) orelse return null;
    return if (member == .string) member.string else null;
}

pub fn equal(value: Value, name: []const u8, expected: []const u8) bool {
    return std.mem.eql(u8, text(value, name) orelse return false, expected);
}

pub fn boolean(value: Value, name: []const u8, expected: bool) bool {
    const member = field(value, name) orelse return false;
    return member == .bool and member.bool == expected;
}

pub fn returned(response: std.json.Parsed(Value)) Value {
    return field(response.value, strings.QMP_RETURN).?;
}

pub fn verifyName(allocator: std.mem.Allocator, connection: *Connection, name: []const u8) !void {
    const named = try command(allocator, connection, strings.QUERY_NAME, null);
    defer named.deinit();
    if (!equal(returned(named), strings.NAME, name)) return error.WrongGuest;
}

pub fn verifyWindow(allocator: std.mem.Allocator, connection: *Connection) !void {
    const response = try command(allocator, connection, strings.QUERY_DISPLAY, null);
    defer response.deinit();
    const backend = text(returned(response), strings.DISPLAY_TYPE) orelse return error.MissingQemuWindow;
    for (strings.WINDOW_BACKENDS) |name| if (std.mem.eql(u8, backend, name)) return;
    if (!builtin.is_test) std.debug.print(strings.WINDOW_REQUIRED, .{backend});
    return error.MissingQemuWindow;
}

pub fn verifyStatus(allocator: std.mem.Allocator, connection: *Connection, expected: []const u8) !void {
    const status = try command(allocator, connection, strings.QUERY_STATUS, null);
    defer status.deinit();
    if (!equal(returned(status), strings.STATUS, expected) or
        !boolean(returned(status), strings.RUNNING, std.mem.eql(u8, expected, strings.RUNNING))) return error.UnexpectedGuestState;
}

pub fn halted(allocator: std.mem.Allocator, connection: *Connection) !bool {
    const registers = try command(allocator, connection, strings.HUMAN_MONITOR, strings.REGISTER_ARGUMENTS);
    defer registers.deinit();
    const result = returned(registers);
    if (result != .string) return error.QmpInvalidResponse;
    var words = std.mem.tokenizeAny(u8, result.string, strings.WHITESPACE);
    while (words.next()) |word| if (std.mem.eql(u8, word, strings.CPU_HALTED)) return true;
    return false;
}

pub fn verifySerial(allocator: std.mem.Allocator, connection: *Connection, path: []const u8) !void {
    const channels = try command(allocator, connection, strings.QUERY_CHARDEV, null);
    defer channels.deinit();
    const device = try channel(returned(channels), strings.SERIAL_LABEL);
    const filename = text(device, strings.FILENAME) orelse return error.WrongGuest;
    if (std.mem.eql(u8, filename, strings.SERIAL_FILE)) return;
    if (!std.mem.startsWith(u8, filename, strings.SERIAL_PREFIX) or
        !try paths.same(allocator, path, filename[strings.SERIAL_PREFIX.len..])) return error.WrongGuest;
}

pub fn verifyControlPort(allocator: std.mem.Allocator, connection: *Connection, label: []const u8, port: u16) !void {
    var buffer: [strings.PHASE_FILENAME.len + 5]u8 = undefined;
    const expected = try std.fmt.bufPrint(&buffer, strings.PHASE_FILENAME, .{port});
    const channels = try command(allocator, connection, strings.QUERY_CHARDEV, null);
    defer channels.deinit();
    const device = try channel(returned(channels), label);
    if (!equal(device, strings.FILENAME, expected)) {
        std.log.err(strings.CONTROL_ENDPOINT_MISMATCH, .{ label, text(device, strings.FILENAME) orelse strings.CONTROL_ENDPOINT_MISSING, expected });
        return error.WrongGuest;
    }
}

fn channel(devices: Value, label: []const u8) !Value {
    if (devices != .array) return error.WrongGuest;
    var matched: ?Value = null;
    for (devices.array.items) |device| {
        if (!equal(device, strings.LABEL, label)) continue;
        if (matched != null or !boolean(device, strings.FRONTEND_OPEN, true)) return error.WrongGuest;
        matched = device;
    }
    return matched orelse error.WrongGuest;
}
