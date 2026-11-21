//! Exercise Real World Startup Recovery And Ordered Shutdown Through Pulse

const std = @import("std");

const completion = @import("tests").guest.completion.support;
const copy = @import("mirai").user.copy.transfer;
const harness = @import("tests").guest.postman.harness;
const inputs = @import("tests").fixtures.constants.service;
const kata = @import("mirai").kata;
const labels = @import("tests").guest.strings.ahci.supervisor;
const locations = @import("tests").guest.constants.postman.transport;
const outcomes = @import("tests").guest.constants.completion.outcomes;
const postman = @import("mirai").postman;
const print = @import("mirai").boot.sequence.print;
const sensei = @import("mirai").sensei;
const thread = @import("mirai").thread;

const Actor = @import("tests").guest.types.postman.fixtures.Actor;
const Operation = @import("tests").guest.types.postman.fixtures.Operation;
const Snapshot = @import("shared").pulse.types.supervision.report.Snapshot;
const WitnessError = @import("tests").guest.errors.ahci.witness.WitnessError;

pub fn diagnose(pulse: u64) !void {
    var client = try harness.create();
    defer harness.dispose(client.ID);
    const operations = [_]Operation{harness.call(&client)} ** inputs.JOBS;
    try harness.install(&client, &operations);
    for (0..inputs.JOBS) |index| {
        const state = try snapshot(&client, pulse, index, index + 1);
        printSnapshot(index, state);
    }
    try harness.advance(&client, inputs.JOBS);
}

fn printSnapshot(ordinal: u64, state: Snapshot) void {
    print.log(labels.SNAPSHOT, .{ ordinal, @intFromEnum(state.Phase), state.Count, state.ID, state.Stage, state.Starts, state.Failures, state.StartedAt, state.StoppedAt });
}

pub fn prove(pulse: u64) !bool {
    var client = try harness.create();
    defer harness.dispose(client.ID);
    var operations: [inputs.STEPS]Operation = undefined;
    @memset(&operations, harness.call(&client));
    operations[6] = .{ .Service = .Send, .First = .{ .Indirect = client.Data + locations.TICKET_OFFSET }, .LetterType = inputs.FAIL };
    try harness.install(&client, &operations);
    const provider = try snapshot(&client, pulse, 0, 1);
    if (provider.Count != inputs.JOBS) return WitnessError.ServiceWorldMissing;
    const consumer = try snapshot(&client, pulse, 1, 2);
    if (provider.ID == 0 or consumer.ID == 0 or provider.Stage != inputs.READY_STAGE or consumer.Stage != inputs.READY_STAGE or
        provider.Starts != 1 or consumer.Starts != 1 or provider.StartedAt >= consumer.StartedAt) return WitnessError.InvalidServiceReadiness;
    const early = try snapshot(&client, pulse, 2, 3);
    const missing = try snapshot(&client, pulse, 3, 4);
    const silent = try snapshot(&client, pulse, 4, 5);
    if (early.ID != 0 or early.Starts != 2 or early.Failures != 2 or early.Stage != inputs.FAILED_STAGE or
        missing.ID != 0 or missing.Starts != 0 or missing.Failures != 1 or missing.Stage != inputs.FAILED_STAGE or
        silent.ID != 0 or silent.Starts != 1 or silent.Failures != 1 or silent.Stage != inputs.FAILED_STAGE)
    {
        printSnapshot(2, early);
        printSnapshot(3, missing);
        printSnapshot(4, silent);
        return WitnessError.InvalidServiceFailure;
    }
    const controller = try snapshot(&client, pulse, 5, 6);
    if (controller.ID == 0 or controller.Stage != inputs.READY_STAGE) return WitnessError.InvalidServiceReadiness;
    try copy.write(client.Owner, client.Data + locations.TICKET_OFFSET, std.mem.asBytes(&provider.ID));
    var observer = try harness.sibling(&client, 1);
    var wait = completion.operation(&observer, outcomes.WAIT);
    wait.First = .{ .Indirect = client.Data + locations.TICKET_OFFSET };
    try harness.install(&observer, &.{wait});
    try harness.start(&observer);
    harness.waitBlocked(&observer) catch return WitnessError.SupervisorObserverNotBlocked;
    try harness.advance(&client, 6);
    try harness.waitStep(&client, 7);
    try harness.check(try harness.resultIs(&client, 7, .Success, 0));
    try harness.waitTimedStep(&observer, 1, inputs.TIMEOUT_TICKS);
    const died = try completion.record(&observer);
    if (!try harness.resultIs(&observer, 1, .Success, outcomes.RECORD_BYTES) or
        died.Kind != outcomes.EXITED or died.Result != inputs.EXIT_RESULT) return WitnessError.InvalidServiceFailure;
    try harness.advance(&observer, 1);
    const recovered = try snapshot(&client, pulse, 0, 8);
    const dependent = try snapshot(&client, pulse, 1, 9);
    if (recovered.ID == 0 or recovered.ID == provider.ID or recovered.Starts != 2 or recovered.Failures != 1 or recovered.Stage != inputs.READY_STAGE or
        dependent.ID == 0 or dependent.ID == consumer.ID or dependent.Starts != 2 or dependent.Stage != inputs.READY_STAGE or
        dependent.StoppedAt == 0 or dependent.StoppedAt >= recovered.StartedAt or recovered.StartedAt >= dependent.StartedAt)
        return WitnessError.InvalidServiceRecovery;
    try harness.descriptorFor(&client, controller.ID, inputs.TRIGGER_SHUTDOWN, 0, 0);
    try harness.advance(&client, 9);
    try harness.waitTimedStep(&client, 10, inputs.TIMEOUT_TICKS);
    const reply = try harness.header(&client);
    if (!try harness.resultIs(&client, 10, .Success, 0) or reply.Sender != controller.ID or reply.Type != inputs.ACK)
        return WitnessError.InvalidSupervisorReply;
    const stopped_consumer = try snapshot(&client, pulse, 1, 11);
    const stopped_provider = try snapshot(&client, pulse, 0, 12);
    const stopped_controller = try snapshot(&client, pulse, 5, 13);
    if (stopped_provider.Phase != .Stopped or stopped_consumer.ID != 0 or stopped_provider.ID != 0 or stopped_controller.ID != 0 or
        stopped_consumer.Stage != inputs.STOPPED_STAGE or stopped_provider.Stage != inputs.STOPPED_STAGE or
        stopped_controller.StoppedAt >= stopped_consumer.StoppedAt or stopped_consumer.StoppedAt >= stopped_provider.StoppedAt or
        stopped_provider.Starts != 2 or stopped_consumer.Starts != 2 or stopped_provider.WeaverID != 0 or stopped_provider.AfsID != 0 or stopped_provider.DiskID != 0 or
        kata.state.findByID(provider.WeaverID) != null or kata.state.findByID(provider.AfsID) != null or kata.state.findByID(provider.DiskID) != null or
        kata.state.findByID(recovered.ID) != null or kata.state.findByID(dependent.ID) != null) return WitnessError.InvalidServiceShutdown;
    try harness.advance(&client, inputs.STEPS);
    return true;
}

fn traceWait() void {
    var current = kata.state.first();
    while (current) |owner| : (current = kata.state.next(owner)) {
        const target = thread.state.firstFor(owner) orelse continue;
        const scheduled = sensei.registry.find(target) orelse continue;
        const record = postman.record.find(target);
        const pending = if (record) |value| value.Pending else null;
        const serving = if (record) |value| value.Serving else null;
        const mailbox = postman.inbox.find(owner);
        print.log(labels.WAIT, .{
            owner.ID,
            kata.completion.storage.ownerOf(owner.ID) orelse 0,
            @intFromEnum(target.Status),
            scheduled.Deadline orelse 0,
            if (pending) |value| value.Header.Type else 0,
            if (pending) |value| if (value.Destination) |destination| destination.ID else 0 else 0,
            if (pending) |value| @as(u64, @intFromEnum(value.Status)) else 0,
            if (serving) |value| value.Header.Type else 0,
            if (mailbox) |value| value.Queued else 0,
        });
    }
}

fn snapshot(client: *const Actor, pulse: u64, index: u64, step: u64) !Snapshot {
    try harness.input(client, std.mem.asBytes(&index));
    try harness.descriptorFor(client, pulse, inputs.REPORT, @sizeOf(u64), @sizeOf(Snapshot));
    if (step == 1) try harness.start(client) else try harness.advance(client, step - 1);
    const ticks = switch (step) {
        8 => inputs.RECOVERY_TICKS,
        11 => inputs.SHUTDOWN_TICKS,
        else => inputs.TIMEOUT_TICKS,
    };
    harness.waitTimedStep(client, step, ticks) catch |failure| {
        traceWait();
        return failure;
    };
    const header = try harness.header(client);
    if (!try harness.resultIs(client, @intCast(step), .Success, @sizeOf(Snapshot)) or header.Sender != pulse or
        header.Type != inputs.SNAPSHOT or header.Length != @sizeOf(Snapshot) or header.ReplyTicket != 0) return WitnessError.InvalidSupervisorReply;
    var result: Snapshot = undefined;
    try copy.read(client.Owner, std.mem.asBytes(&result), client.Data + locations.OUTPUT_OFFSET);
    return result;
}
