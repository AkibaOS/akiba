//! Real Persona Postman Fixture Lifetime And Driving

const std = @import("std");

const abi = @import("shared").persona.types.invocation;
const arguments = @import("shared").persona.types.call;
const constants = @import("tests").guest.constants.postman.transport;
const copy = @import("mirai").user.copy.transfer;
const guard = @import("asm").interrupts.guard;
const kata = @import("mirai").kata;
const limits = @import("tests").guest.constants.guest;
const postman = @import("mirai").postman;
const postmanwire = @import("tests").fixtures.constants.postman;
const print = @import("mirai").boot.sequence.print;
const program = @import("tests").guest.postman.program;
const sensei = @import("mirai").sensei;
const strings = @import("tests").guest.strings.postman.witnesses;
const support = @import("tests").guest.sensei.support;
const thread = @import("mirai").thread;
const timing = @import("tests").guest.strings.postman.deadline;
const types = @import("tests").guest.types.postman.fixtures;
const user = @import("mirai").user;

const Actor = types.Actor;
const FixtureError = types.FixtureError;
const Header = @import("shared").persona.types.letter.Header;
const InvocationResult = types.InvocationResult;
const Operation = types.Operation;
const Resources = types.Resources;

pub fn create() !Actor {
    const owner = try kata.create.create();
    errdefer dispose(owner.ID);
    return allocate(owner, 0);
}

pub fn child(actor: *const Actor) !Actor {
    const owner = try kata.create.createFor(actor.Owner);
    errdefer dispose(owner.ID);
    return allocate(owner, 0);
}

pub fn sibling(actor: *const Actor, slot: usize) !Actor {
    if (slot == 0 or slot > 2) return FixtureError.InvalidFixture;
    return allocate(actor.Owner, slot);
}

fn allocate(owner: *kata.types.kata.Kata, slot: usize) !Actor {
    const actor: Actor = .{
        .Owner = owner,
        .ID = owner.ID,
        .Code = constants.CODE_BASE + slot * constants.PAGE_BYTES,
        .Data = constants.DATA_BASE + slot * constants.PAGE_BYTES,
        .Stack = constants.STACK_BASE + slot * 2 * constants.PAGE_BYTES,
    };
    try user.memory.allocate.allocate(owner, actor.Code);
    try user.memory.allocate.allocate(owner, actor.Data);
    try user.memory.allocate.allocate(owner, actor.Stack);
    var data: [constants.PAGE_BYTES]u8 = @splat(constants.GUARD_BYTE);
    @memset(data[0..constants.RESULT_OFFSET], 0);
    @memcpy(data[constants.INPUT_OFFSET..][0..constants.REQUEST.len], &constants.REQUEST);
    try user.memory.load.load(owner, actor.Data, &data);
    try user.memory.finalize.finalize(owner, actor.Data, .ReadWrite);
    try user.memory.finalize.finalize(owner, actor.Stack, .ReadWrite);
    return actor;
}

pub fn install(actor: *Actor, operations: []const Operation) !void {
    if (actor.Target != null) return FixtureError.InvalidFixture;
    const encoded = try program.encode(actor, operations);
    try user.memory.load.load(actor.Owner, actor.Code, encoded.Bytes[0..encoded.Length]);
    try user.memory.finalize.finalize(actor.Owner, actor.Code, .ReadExecute);
    actor.Target = try thread.user.create(actor.Owner, actor.Code, actor.Stack, constants.PAGE_BYTES, 0);
}

pub fn start(actor: *const Actor) !void {
    try sensei.control.start(actor.Target orelse return FixtureError.InvalidFixture);
}

pub fn waitStep(actor: *const Actor, step: u64) !void {
    var attempts: usize = 0;
    while (attempts < limits.DRIVE_LIMIT) : (attempts += 1) {
        var progress: u64 = 0;
        try copy.read(actor.Owner, std.mem.asBytes(&progress), actor.Data + @sizeOf(u64));
        if (progress >= step) return;
        try sensei.run.yield();
    }
    return FixtureError.DriveLimit;
}

pub fn waitTimedStep(actor: *const Actor, step: u64, ticks: u64) !void {
    const until = sensei.state.getState().Ticks + ticks + 2 * sensei.constants.policy.QUANTUM_TICKS;
    while (sensei.state.getState().Ticks <= until) {
        var progress: u64 = 0;
        try copy.read(actor.Owner, std.mem.asBytes(&progress), actor.Data + @sizeOf(u64));
        if (progress >= step) return;
        try sensei.run.yield();
    }
    const scheduled = sensei.registry.find(actor.Target.?) orelse return FixtureError.DriveLimit;
    var progress: u64 = 0;
    try copy.read(actor.Owner, std.mem.asBytes(&progress), actor.Data + @sizeOf(u64));
    print.log(timing.WAIT, .{ sensei.state.getState().Ticks, until, scheduled.Deadline orelse 0, @as(u64, if (scheduled.TimedOut) 1 else 0), @intFromEnum(actor.Target.?.Status), progress });
    return FixtureError.DriveLimit;
}

pub fn waitBlocked(actor: *const Actor) !void {
    const target = actor.Target orelse return FixtureError.InvalidFixture;
    var attempts: usize = 0;
    while (attempts < limits.DRIVE_LIMIT) : (attempts += 1) {
        const flags = guard.acquire();
        const blocked = target.Status == .Blocked;
        guard.release(flags);
        if (blocked) return;
        try sensei.run.yield();
    }
    return FixtureError.DriveLimit;
}

pub fn advance(actor: *const Actor, step: u64) !void {
    try copy.write(actor.Owner, actor.Data, std.mem.asBytes(&step));
}

pub fn resultIs(actor: *const Actor, step: usize, status: abi.Status, value: u64) !bool {
    var result: InvocationResult = undefined;
    try copy.read(actor.Owner, std.mem.asBytes(&result), actor.Data + constants.RESULT_OFFSET + (step - 1) * @sizeOf(InvocationResult));
    return result.Status == @intFromEnum(status) and result.Value == value;
}

pub fn header(actor: *const Actor) !Header {
    var result: Header = undefined;
    try copy.read(actor.Owner, std.mem.asBytes(&result), actor.Data + constants.HEADER_OFFSET);
    return result;
}

pub fn payloadIs(actor: *const Actor, expected: []const u8) !bool {
    var output: [constants.OUTPUT_BYTES]u8 = undefined;
    try copy.read(actor.Owner, &output, actor.Data + constants.OUTPUT_OFFSET);
    if (!std.mem.eql(u8, expected, output[0..expected.len])) return false;
    for (output[expected.len..]) |byte| if (byte != constants.GUARD_BYTE) return false;
    return true;
}

pub fn untouched(actor: *const Actor) !bool {
    var output: [constants.OUTPUT_BYTES]u8 = undefined;
    var metadata: [@sizeOf(Header)]u8 = undefined;
    try copy.read(actor.Owner, &output, actor.Data + constants.OUTPUT_OFFSET);
    try copy.read(actor.Owner, &metadata, actor.Data + constants.HEADER_OFFSET);
    for (output) |byte| if (byte != constants.GUARD_BYTE) return false;
    for (metadata) |byte| if (byte != constants.GUARD_BYTE) return false;
    return true;
}

pub fn input(actor: *const Actor, bytes: []const u8) !void {
    try copy.write(actor.Owner, actor.Data + constants.INPUT_OFFSET, bytes);
}

pub fn descriptor(actor: *const Actor, destination: u64, capacity: u64) !void {
    return descriptorFor(actor, destination, postmanwire.CALL_TYPE, constants.REQUEST.len, capacity);
}

pub fn descriptorFor(actor: *const Actor, destination: u64, letter_type: u64, length: u64, capacity: u64) !void {
    const value: arguments.Call = .{
        .Destination = destination,
        .Type = letter_type,
        .Request = actor.Data + constants.INPUT_OFFSET,
        .RequestLength = length,
        .Reply = actor.Data + constants.OUTPUT_OFFSET,
        .ReplyCapacity = capacity,
        .Metadata = actor.Data + constants.HEADER_OFFSET,
    };
    try copy.write(actor.Owner, actor.Data + constants.CALL_OFFSET, std.mem.asBytes(&value));
}

pub fn mailbox(actor: *const Actor) !*postman.types.mailbox.queues.Mailbox {
    return postman.inbox.find(actor.Owner) orelse FixtureError.InvalidFixture;
}

pub fn record(actor: *const Actor) !*postman.types.record.delivery.Record {
    return postman.record.find(actor.Target orelse return FixtureError.InvalidFixture) orelse FixtureError.InvalidFixture;
}

pub fn send(actor: *const Actor, destination: u64, letter_type: u64, length: u64) Operation {
    return .{
        .Service = .Send,
        .First = .{ .Immediate = destination },
        .Second = if (length == 0) 0 else actor.Data + constants.INPUT_OFFSET,
        .Third = length,
        .LetterType = letter_type,
    };
}

pub fn receive(actor: *const Actor, capacity: u64) Operation {
    return .{
        .Service = .Receive,
        .First = .{ .Immediate = if (capacity == 0) 0 else actor.Data + constants.OUTPUT_OFFSET },
        .Second = capacity,
        .Third = actor.Data + constants.HEADER_OFFSET,
    };
}

pub fn call(actor: *const Actor) Operation {
    return .{ .Service = .Call, .First = .{ .Immediate = actor.Data + constants.CALL_OFFSET } };
}

pub fn reply(actor: *const Actor) Operation {
    return .{
        .Service = .Reply,
        .First = .{ .Indirect = actor.Data + constants.HEADER_OFFSET + 3 * @sizeOf(u64) },
        .Second = actor.Data + constants.INPUT_OFFSET,
        .Third = constants.REPLY.len,
        .LetterType = postmanwire.REPLY_TYPE,
    };
}

pub fn collect(actor: *const Actor, capacity: u64) Operation {
    var operation = receive(actor, capacity);
    operation.Service = .CollectReply;
    return operation;
}

pub fn check(condition: bool) FixtureError!void {
    if (!condition) return FixtureError.InvalidFixture;
}

pub fn resources() Resources {
    const flags = guard.acquire();
    defer guard.release(flags);
    var result: Resources = .{};
    result.Envelopes = postman.storage.count();
    var owner = kata.state.first();
    while (owner) |current| {
        if (postman.inbox.find(current) != null) result.Mailboxes += 1;
        owner = kata.state.next(current);
    }
    var target = thread.state.first();
    while (target) |current| {
        if (postman.record.find(current) != null) result.Records += 1;
        target = thread.state.next(current);
    }
    return result;
}

pub fn dispose(identifier: u64) void {
    support.dispose(identifier) catch @panic(strings.CLEANUP_FAILED);
}
