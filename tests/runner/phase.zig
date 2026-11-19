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

pub fn select(stream: std.net.Stream, instance: *Process, timer: *std.time.Timer, evidence: Epoch, ticket: phase.types.ticket.Ticket) !void {
    const offer = phase.wire.encode(ticket, .Offer) orelse return error.InvalidPhaseOffer;
    const deadline: Deadline = .{ .Timer = timer, .Limit = limits.CHECK_NS };
    try greeting(stream, instance, deadline, evidence, &phase.constants.wire.READY);
    try send(stream, instance, deadline, &offer);
    var acknowledgement: phase.types.ticket.Frame = undefined;
    try receive(stream, instance, deadline, &acknowledgement, null);
    _ = try remaining(instance, deadline);
    if (!phase.wire.acknowledges(ticket, &acknowledgement)) return error.InvalidPhaseAcknowledgement;
}

pub fn choose(stream: std.net.Stream, instance: *Process, timer: *std.time.Timer, evidence: Epoch, summary: phase.types.menu.Offer) !phase.types.action.Action {
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
    receive(stream, instance, idle, response[0..1], evidence) catch |failure| switch (failure) {
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

fn receive(stream: std.net.Stream, instance: ?*Process, deadline: Deadline, bytes: []u8, evidence: ?Epoch) !void {
    var received: usize = 0;
    while (received < bytes.len) {
        _ = try remaining(instance, deadline);
        const count = socket.receive(stream.handle, bytes[received..]) catch |failure| switch (@as(anyerror, failure)) {
            error.WouldBlock, error.ConnectionTimedOut => {
                try wait(stream, instance, deadline, std.posix.POLL.IN, evidence);
                continue;
            },
            else => return failure,
        };
        if (count == 0) return error.PhaseChannelDisconnected;
        received += count;
    }
}

fn send(stream: std.net.Stream, instance: *Process, deadline: Deadline, bytes: []const u8) !void {
    var sent: usize = 0;
    while (sent < bytes.len) {
        _ = try remaining(instance, deadline);
        const count = socket.send(stream.handle, bytes[sent..]) catch |failure| switch (@as(anyerror, failure)) {
            error.WouldBlock, error.ConnectionTimedOut => {
                try wait(stream, instance, deadline, std.posix.POLL.OUT, null);
                continue;
            },
            else => return failure,
        };
        if (count == 0) return error.PhaseChannelDisconnected;
        sent += count;
    }
}

fn wait(stream: std.net.Stream, instance: ?*Process, deadline: Deadline, events: i16, evidence: ?Epoch) !void {
    var descriptors = [_]std.posix.pollfd{.{ .fd = stream.handle, .events = events, .revents = 0 }};
    while (true) {
        const nanoseconds = @min(try remaining(instance, deadline), limits.POLL_NS);
        const ready = try std.posix.poll(&descriptors, @intCast(nanoseconds / std.time.ns_per_ms));
        if (ready != 0) {
            _ = try remaining(instance, deadline);
            const observed = descriptors[0].revents;
            if ((observed & (std.posix.POLL.ERR | std.posix.POLL.NVAL | std.posix.POLL.HUP)) != 0) return error.PhaseChannelDisconnected;
            if ((observed & events) != 0) return;
        }
        if (evidence) |epoch| try checkSerial(epoch);
    }
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
