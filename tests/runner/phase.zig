//! Bounded Host Phase Ticket Exchange

const std = @import("std");

const limits = @import("tests").constants.runner;
const phase = @import("tests").phase;
const process = @import("tests").runner.process;
const result = @import("tests").runner.result;
const serial = @import("tests").runner.serial;
const socket = @import("tests").runner.socket;
const Epoch = @import("tests").types.host.Epoch;
const Process = @import("tests").types.host.Process;

pub fn open(port: u16, instance: *Process, timer: *std.time.Timer) !std.net.Stream {
    _ = try remaining(instance, timer);
    const stream = try socket.startConnection(port);
    errdefer stream.close();
    try wait(stream, instance, timer, std.posix.POLL.OUT, null);
    try socket.checkConnection(stream);
    return stream;
}

pub fn select(stream: std.net.Stream, instance: *Process, timer: *std.time.Timer, evidence: Epoch, ticket: phase.types.ticket.Ticket) !void {
    const offer = phase.wire.encode(ticket, .Offer) orelse return error.InvalidPhaseOffer;
    try checkSerial(evidence);
    var matched: usize = 0;
    while (matched < phase.constants.wire.READY.len) {
        var next: [1]u8 = undefined;
        try receive(stream, instance, timer, &next, evidence);
        matched = phase.wire.advanceGreeting(matched, next[0]);
    }
    try send(stream, instance, timer, &offer);
    var acknowledgement: phase.types.ticket.Frame = undefined;
    try receive(stream, instance, timer, &acknowledgement, null);
    _ = try remaining(instance, timer);
    if (!phase.wire.acknowledges(ticket, &acknowledgement)) return error.InvalidPhaseAcknowledgement;
}

fn receive(stream: std.net.Stream, instance: *Process, timer: *std.time.Timer, bytes: []u8, evidence: ?Epoch) !void {
    var received: usize = 0;
    while (received < bytes.len) {
        _ = try remaining(instance, timer);
        const count = socket.receive(stream.handle, bytes[received..]) catch |failure| switch (@as(anyerror, failure)) {
            error.WouldBlock, error.ConnectionTimedOut => {
                try wait(stream, instance, timer, std.posix.POLL.IN, evidence);
                continue;
            },
            else => return failure,
        };
        if (count == 0) return error.PhaseChannelDisconnected;
        received += count;
    }
}

fn send(stream: std.net.Stream, instance: *Process, timer: *std.time.Timer, bytes: []const u8) !void {
    var sent: usize = 0;
    while (sent < bytes.len) {
        _ = try remaining(instance, timer);
        const count = socket.send(stream.handle, bytes[sent..]) catch |failure| switch (@as(anyerror, failure)) {
            error.WouldBlock, error.ConnectionTimedOut => {
                try wait(stream, instance, timer, std.posix.POLL.OUT, null);
                continue;
            },
            else => return failure,
        };
        if (count == 0) return error.PhaseChannelDisconnected;
        sent += count;
    }
}

fn wait(stream: std.net.Stream, instance: *Process, timer: *std.time.Timer, events: i16, evidence: ?Epoch) !void {
    var descriptors = [_]std.posix.pollfd{.{ .fd = stream.handle, .events = events, .revents = 0 }};
    while (true) {
        const nanoseconds = @min(try remaining(instance, timer), limits.POLL_NS);
        const ready = try std.posix.poll(&descriptors, @intCast(nanoseconds / std.time.ns_per_ms));
        if (ready != 0) {
            _ = try remaining(instance, timer);
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

fn remaining(instance: *Process, timer: *std.time.Timer) !u64 {
    if (process.cancelled()) return error.Cancelled;
    if (try process.exited(instance)) return error.GuestExited;
    const elapsed = timer.read();
    if (elapsed >= limits.CHECK_NS) return error.GuestPhaseTimeout;
    return limits.CHECK_NS - elapsed;
}
