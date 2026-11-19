//! Bounded Host Diagnostic Serial Exchange

const std = @import("std");

const limits = @import("tests").constants.runner;
const phase = @import("tests").phase;
const process = @import("tests").runner.process;
const result = @import("tests").runner.result;
const serial = @import("tests").runner.serial;
const socket = @import("tests").runner.socket;
const strings = @import("tests").strings.runner;
const CancelChannel = @import("tests").types.host.CancelChannel;
const Deadline = @import("tests").types.host.Deadline;
const Epoch = @import("tests").types.host.Epoch;
const Process = @import("tests").types.host.Process;

pub fn open(port: u16, instance: *Process, timer: *std.time.Timer) !std.net.Stream {
    const deadline: Deadline = .{ .Timer = timer, .Limit = limits.CHECK_NS };
    _ = try remaining(instance, deadline);
    const stream = try socket.startConnection(port);
    errdefer stream.close();
    try wait(stream, instance, deadline, std.posix.POLL.OUT, null);
    try socket.checkConnection(stream);
    return stream;
}

pub fn selectBoot(stream: std.net.Stream, instance: *Process, timer: *std.time.Timer, evidence: Epoch, selection: phase.types.boot.Selection) !void {
    const offer = phase.boot.encode(selection, .Offer) orelse return error.InvalidBootSelection;
    const deadline: Deadline = .{ .Timer = timer, .Limit = limits.START_NS };
    try greeting(stream, instance, deadline, evidence, &phase.constants.boot.READY);
    try send(stream, instance, deadline, &offer);
    var acknowledgement: phase.types.boot.Frame = undefined;
    try receive(stream, instance, deadline, &acknowledgement, evidence);
    _ = try remaining(instance, deadline);
    if (!phase.boot.acknowledges(selection, &acknowledgement)) return error.InvalidBootAcknowledgement;
}

pub fn start(stream: std.net.Stream, instance: *Process, timer: *std.time.Timer, evidence: Epoch, context: phase.types.live.Offer) !void {
    const offer = phase.live.encodeOffer(context) orelse return error.InvalidPhaseOffer;
    const deadline: Deadline = .{ .Timer = timer, .Limit = limits.CHECK_NS };
    try greeting(stream, instance, deadline, evidence, &phase.constants.live.READY);
    try send(stream, instance, deadline, &offer);
    var acknowledgement: phase.types.live.Acknowledgement = undefined;
    try receive(stream, instance, deadline, &acknowledgement, evidence);
    _ = try remaining(instance, deadline);
    if (!phase.live.acknowledges(context.Ticket, &acknowledgement)) return error.InvalidPhaseAcknowledgement;
}

pub fn choose(stream: std.net.Stream, instance: *Process, timer: *std.time.Timer, evidence: Epoch, summary: phase.types.menu.Offer) !phase.types.action.Action {
    comptime std.debug.assert(limits.MENU_NS == @as(u64, phase.constants.menu.COUNTDOWN_SECONDS) * std.time.ns_per_s);
    const offer = phase.menu.encodeOffer(summary) orelse return error.InvalidMenuOffer;
    const deadline: Deadline = .{ .Timer = timer, .Limit = limits.START_NS };
    try greeting(stream, instance, deadline, evidence, &phase.constants.menu.READY);
    try send(stream, instance, deadline, &offer);
    var ready: phase.types.menu.ArmedFrame = undefined;
    try receive(stream, instance, deadline, &ready, evidence);
    if (!phase.menu.isArmed(summary.Epoch, &ready)) return error.InvalidMenuAcknowledgement;
    var timer_after_arm = try std.time.Timer.start();
    std.debug.print(strings.MENU_READY, .{});
    return menuAction(stream, instance, .{ .Timer = &timer_after_arm, .Limit = limits.MENU_NS }, evidence, summary.Epoch);
}

pub fn menuAction(stream: std.net.Stream, instance: ?*Process, idle: Deadline, evidence: ?Epoch, epoch: u64) !phase.types.action.Action {
    var response: phase.types.action.Frame = undefined;
    receiveMenuStart(stream, instance, idle, response[0..1], evidence, epoch) catch |failure| switch (failure) {
        error.GuestPhaseTimeout => {
            if (evidence) |log| try checkSerial(log);
            return .Timeout;
        },
        else => return failure,
    };
    var frame_timer = try std.time.Timer.start();
    const tail: Deadline = .{ .Timer = &frame_timer, .Limit = limits.MENU_FRAME_NS };
    try receive(stream, instance, tail, response[1..], evidence);
    _ = try remaining(instance, tail);
    return phase.action.decode(&response, epoch, .Menu) orelse return error.InvalidMenuAction;
}

pub fn cancellation(channel: *CancelChannel) !bool {
    if (channel.Received < channel.Frame.len) {
        const count = socket.receive(channel.Stream.handle, channel.Frame[channel.Received..]) catch |failure| switch (@as(anyerror, failure)) {
            error.WouldBlock, error.ConnectionTimedOut => return false,
            else => return failure,
        };
        if (count == 0) return error.PhaseChannelDisconnected;
        channel.Received += count;
    }
    if (channel.Received != channel.Frame.len) return false;
    if (phase.action.decode(&channel.Frame, channel.Epoch, .Testing) != .Cancel) return error.InvalidCancellationAction;
    return true;
}

fn greeting(stream: std.net.Stream, instance: *Process, deadline: Deadline, evidence: Epoch, marker: []const u8) !void {
    try checkSerial(evidence);
    var matched: usize = 0;
    while (matched < marker.len) {
        var next: [1]u8 = undefined;
        try receive(stream, instance, deadline, &next, evidence);
        matched = phase.wire.advanceGreeting(marker, matched, next[0]);
    }
}

fn receiveMenuStart(stream: std.net.Stream, instance: ?*Process, idle: Deadline, first: []u8, evidence: ?Epoch, epoch: u64) !void {
    var tick: phase.types.menu.CountdownFrame = undefined;
    var sent: usize = tick.len;
    var scheduled_seconds = countdownSeconds(idle.Limit);
    while (true) {
        const nanoseconds = try remaining(instance, idle);
        if (try receiveAvailable(stream, first) != 0) return;
        const seconds = countdownSeconds(nanoseconds);
        if (seconds != scheduled_seconds and (sent == 0 or sent == tick.len)) {
            tick = phase.menu.encodeCountdown(epoch, seconds) orelse return error.InvalidMenuCountdown;
            scheduled_seconds = seconds;
            sent = 0;
        }
        if (sent < tick.len) sent += try sendAvailable(stream, tick[sent..]);
        const until_tick = (nanoseconds - 1) % std.time.ns_per_s + 1;
        if (!try poll(stream, instance, idle, std.posix.POLL.IN, @min(until_tick, limits.POLL_NS))) {
            if (evidence) |log| try checkSerial(log);
        }
    }
}

fn countdownSeconds(nanoseconds: u64) u8 {
    const rounded = nanoseconds / std.time.ns_per_s + @intFromBool(nanoseconds % std.time.ns_per_s != 0);
    return @intCast(@min(rounded, phase.constants.menu.COUNTDOWN_SECONDS));
}

fn receive(stream: std.net.Stream, instance: ?*Process, deadline: Deadline, bytes: []u8, evidence: ?Epoch) !void {
    var received: usize = 0;
    while (received < bytes.len) {
        _ = try remaining(instance, deadline);
        const count = try receiveAvailable(stream, bytes[received..]);
        if (count == 0) try wait(stream, instance, deadline, std.posix.POLL.IN, evidence);
        received += count;
    }
}

fn receiveAvailable(stream: std.net.Stream, bytes: []u8) !usize {
    const count = socket.receive(stream.handle, bytes) catch |failure| switch (@as(anyerror, failure)) {
        error.WouldBlock, error.ConnectionTimedOut => return 0,
        else => return failure,
    };
    if (count == 0) return error.PhaseChannelDisconnected;
    return count;
}

fn send(stream: std.net.Stream, instance: *Process, deadline: Deadline, bytes: []const u8) !void {
    var sent: usize = 0;
    while (sent < bytes.len) {
        _ = try remaining(instance, deadline);
        const count = try sendAvailable(stream, bytes[sent..]);
        if (count == 0) try wait(stream, instance, deadline, std.posix.POLL.OUT, null);
        sent += count;
    }
}

fn sendAvailable(stream: std.net.Stream, bytes: []const u8) !usize {
    const count = socket.send(stream.handle, bytes) catch |failure| switch (@as(anyerror, failure)) {
        error.WouldBlock, error.ConnectionTimedOut => return 0,
        else => return failure,
    };
    if (count == 0) return error.PhaseChannelDisconnected;
    return count;
}

fn wait(stream: std.net.Stream, instance: ?*Process, deadline: Deadline, events: i16, evidence: ?Epoch) !void {
    while (!try poll(stream, instance, deadline, events, limits.POLL_NS)) {
        if (evidence) |epoch| try checkSerial(epoch);
    }
}

fn poll(stream: std.net.Stream, instance: ?*Process, deadline: Deadline, events: i16, interval: u64) !bool {
    var descriptors = [_]std.posix.pollfd{.{ .fd = stream.handle, .events = events, .revents = 0 }};
    const nanoseconds = @min(try remaining(instance, deadline), interval);
    if (try std.posix.poll(&descriptors, @intCast(nanoseconds / std.time.ns_per_ms)) == 0) return false;
    _ = try remaining(instance, deadline);
    const observed = descriptors[0].revents;
    if ((observed & (std.posix.POLL.ERR | std.posix.POLL.NVAL | std.posix.POLL.HUP)) != 0) return error.PhaseChannelDisconnected;
    return (observed & events) != 0;
}

fn checkSerial(evidence: Epoch) !void {
    const bytes = try serial.read(std.heap.page_allocator, evidence);
    defer std.heap.page_allocator.free(bytes);
    if (result.failedBeforeSelection(bytes)) return error.GuestCheckFailed;
}

fn remaining(instance: ?*Process, deadline: Deadline) !u64 {
    if (process.cancelled()) return error.Cancelled;
    if (instance) |child| if (try process.exited(child)) return error.GuestExited;
    const elapsed = deadline.Timer.read();
    if (elapsed >= deadline.Limit) return error.GuestPhaseTimeout;
    return deadline.Limit - elapsed;
}
