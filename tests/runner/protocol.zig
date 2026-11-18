//! Bounded Owned Guest QMP Protocol

const std = @import("std");

const limits = @import("tests").constants.runner;
const paths = @import("tests").runner.paths;
const process = @import("tests").runner.process;
const socket = @import("tests").runner.socket;
const strings = @import("tests").strings.runner;
const types = @import("tests").types.host;

const Connection = types.Connection;
const Paths = types.Paths;
const Value = std.json.Value;

fn checkDeadline(timer: *std.time.Timer, ignore_cancel: bool) !void {
    if (!ignore_cancel and process.cancelled()) return error.Cancelled;
    if (timer.read() >= limits.PROTOCOL_NS) return error.QmpOperationTimeout;
}

fn readLine(allocator: std.mem.Allocator, connection: *Connection, timer: *std.time.Timer, ignore_cancel: bool) ![]u8 {
    var bytes: std.ArrayList(u8) = .empty;
    errdefer bytes.deinit(allocator);
    while (bytes.items.len < limits.MAX_PACKET_BYTES) {
        try checkDeadline(timer, ignore_cancel);
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
    const greeting = try readLine(allocator, &connection, &timer, false);
    defer allocator.free(greeting);
    const parsed = try std.json.parseFromSlice(Value, allocator, greeting, .{});
    defer parsed.deinit();
    if (field(parsed.value, strings.QMP_MEMBER) == null) return error.QmpInvalidGreeting;
    const capabilities = try command(allocator, &connection, strings.CAPABILITIES);
    capabilities.deinit();
    return connection;
}

pub fn command(allocator: std.mem.Allocator, connection: *Connection, name: []const u8) !std.json.Parsed(Value) {
    return sendRequest(allocator, connection, name, null, false);
}

pub fn quit(allocator: std.mem.Allocator, connection: *Connection) !void {
    const response = try sendRequest(allocator, connection, strings.QUIT, null, true);
    response.deinit();
}

pub fn pressKey(allocator: std.mem.Allocator, connection: *Connection) !void {
    const response = try sendRequest(allocator, connection, strings.SEND_KEY, strings.KEY_ARGUMENTS, false);
    response.deinit();
}

fn sendRequest(allocator: std.mem.Allocator, connection: *Connection, name: []const u8, arguments: ?[]const u8, ignore_cancel: bool) !std.json.Parsed(Value) {
    var timer = try std.time.Timer.start();
    connection.Sequence += 1;
    const request = if (arguments) |values|
        try std.fmt.allocPrint(allocator, strings.QMP_ARGUMENT_REQUEST, .{ name, values, connection.Sequence })
    else
        try std.fmt.allocPrint(allocator, strings.QMP_REQUEST, .{ name, connection.Sequence });
    defer allocator.free(request);
    var sent: usize = 0;
    while (sent < request.len) {
        try checkDeadline(&timer, ignore_cancel);
        const count = try socket.send(connection.Stream.handle, request[sent..]);
        if (count == 0) return error.QmpDisconnected;
        sent += count;
    }
    var count: usize = 0;
    while (count < limits.MAX_PACKETS) : (count += 1) {
        const line = try readLine(allocator, connection, &timer, ignore_cancel);
        defer allocator.free(line);
        const parsed = try std.json.parseFromSlice(Value, allocator, line, .{ .allocate = .alloc_always });
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

fn field(value: Value, name: []const u8) ?Value {
    return if (value == .object) value.object.get(name) else null;
}

fn text(value: Value, name: []const u8) ?[]const u8 {
    const member = field(value, name) orelse return null;
    return if (member == .string) member.string else null;
}

fn equal(value: Value, name: []const u8, expected: []const u8) bool {
    return std.mem.eql(u8, text(value, name) orelse return false, expected);
}

fn imageMatches(allocator: std.mem.Allocator, value: Value, expected: []const u8, readonly: bool) !bool {
    const ro = field(value, strings.READONLY) orelse return false;
    const active = field(value, strings.ACTIVE) orelse return false;
    const image = field(value, strings.IMAGE) orelse return false;
    const backing = field(image, strings.BACKING_IMAGE) orelse return false;
    if (ro != .bool or ro.bool != readonly or active != .bool or !active.bool or !equal(backing, strings.FORMAT, strings.RAW)) return false;
    return try paths.same(allocator, expected, text(backing, strings.FILENAME) orelse return false) and
        try paths.same(allocator, expected, text(value, strings.BACKING_FILE) orelse return false);
}

pub fn verify(allocator: std.mem.Allocator, connection: *Connection, inputs: *const Paths, name: []const u8) !void {
    return verifyState(allocator, connection, inputs, name, strings.RUNNING, error.GuestNotRunning);
}

pub fn verifyPaused(allocator: std.mem.Allocator, connection: *Connection, inputs: *const Paths, name: []const u8) !void {
    return verifyState(allocator, connection, inputs, name, strings.PRELAUNCH, error.GuestNotPaused);
}

fn verifyState(allocator: std.mem.Allocator, connection: *Connection, inputs: *const Paths, name: []const u8, expected: []const u8, state_error: anyerror) !void {
    const named = try command(allocator, connection, strings.QUERY_NAME);
    defer named.deinit();
    if (!equal(field(named.value, strings.QMP_RETURN).?, strings.NAME, name)) return error.WrongGuest;
    const status = try command(allocator, connection, strings.QUERY_STATUS);
    defer status.deinit();
    if (!equal(field(status.value, strings.QMP_RETURN).?, strings.STATUS, expected)) return state_error;
    const blocks = try command(allocator, connection, strings.QUERY_BLOCK);
    defer blocks.deinit();
    const devices = field(blocks.value, strings.QMP_RETURN).?;
    if (devices != .array) return error.WrongGuest;
    var matched: usize = 0;
    var inserted: usize = 0;
    for (devices.array.items) |device| {
        const image = field(device, strings.INSERTED) orelse continue;
        inserted += 1;
        if (equal(device, strings.DEVICE, strings.FLASH_CODE) and try imageMatches(allocator, image, inputs.FirmwareCode, true)) matched += 1;
        if (equal(device, strings.DEVICE, strings.FLASH_VARS) and try imageMatches(allocator, image, inputs.Variables, false)) matched += 1;
        if (equal(device, strings.DEVICE, strings.DISK) and try imageMatches(allocator, image, inputs.Image, false)) matched += 1;
    }
    if (matched != 3 or inserted != 3) return error.WrongGuest;
    const characters = try command(allocator, connection, strings.QUERY_CHARDEV);
    defer characters.deinit();
    const devices_serial = field(characters.value, strings.QMP_RETURN).?;
    if (devices_serial != .array) return error.WrongGuest;
    var serial_matched: usize = 0;
    for (devices_serial.array.items) |device| {
        if (!equal(device, strings.LABEL, strings.SERIAL_LABEL)) continue;
        const filename = text(device, strings.FILENAME) orelse return error.WrongGuest;
        if (!std.mem.eql(u8, filename, strings.SERIAL_FILE)) {
            if (!std.mem.startsWith(u8, filename, strings.SERIAL_PREFIX) or
                !try paths.same(allocator, inputs.Serial, filename[strings.SERIAL_PREFIX.len..])) return error.WrongGuest;
        }
        serial_matched += 1;
    }
    if (serial_matched != 1) return error.WrongGuest;
}

pub fn verifyPhasePort(allocator: std.mem.Allocator, connection: *Connection, port: u16) !void {
    var buffer: [strings.PHASE_FILENAME.len + 5]u8 = undefined;
    const expected = try std.fmt.bufPrint(&buffer, strings.PHASE_FILENAME, .{port});
    const channels = try command(allocator, connection, strings.QUERY_CHARDEV);
    defer channels.deinit();
    const result = field(channels.value, strings.QMP_RETURN).?;
    if (result != .array) return error.WrongGuest;
    var matches: usize = 0;
    for (result.array.items) |channel| {
        if (!equal(channel, strings.LABEL, strings.PHASE_LABEL)) continue;
        const opened = field(channel, strings.FRONTEND_OPEN) orelse return error.WrongGuest;
        if (opened != .bool or !opened.bool or !equal(channel, strings.FILENAME, expected)) return error.WrongGuest;
        matches += 1;
    }
    if (matches != 1) return error.WrongGuest;
}
