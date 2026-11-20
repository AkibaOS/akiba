//! Persona Completion Fixture Operations And Child Ownership

const std = @import("std");

const access = @import("tests").guest.constants.access;
const common = @import("common");
const copy = @import("mirai").user.copy.transfer;
const guard = @import("asm").interrupts.guard;
const harness = @import("tests").guest.postman.harness;
const inputs = @import("tests").guest.constants.completion.outcomes;
const kata = @import("mirai").kata;
const limits = @import("tests").guest.constants.guest;
const locations = @import("tests").guest.constants.postman.transport;
const scheduling = @import("tests").guest.sensei.support;
const sensei = @import("mirai").sensei;
const thread = @import("mirai").thread;
const types = @import("tests").guest.types.completion.outcomes;
const user = @import("mirai").user;
const values = @import("tests").guest.types.postman.fixtures;
const verify = @import("tests").guest.support.verify;

const Actor = values.Actor;
const Entry = thread.types.entry.callback.Entry;
const Kata = kata.types.kata.Kata;

var parked: sensei.types.queue.links.Queue = .{};

pub fn operation(actor: *const Actor, service: u64) values.Operation {
    return .{
        .Service = .Query,
        .ServiceValue = service,
        .First = .{ .Indirect = actor.Data + locations.INPUT_OFFSET },
        .Second = actor.Data + locations.OUTPUT_OFFSET,
        .Third = inputs.RECORD_BYTES,
    };
}

pub fn identify(actor: *const Actor, identifier: u64) !void {
    try harness.input(actor, std.mem.asBytes(&identifier));
}

pub fn child(launcher: *Kata, entry: Entry) !types.Target {
    const owner = try kata.create.createFor(launcher);
    const identifier = owner.ID;
    errdefer dispose(identifier);
    const target = try thread.create.create(owner, entry, null);
    try sensei.control.start(target);
    return .{ .ID = identifier, .Thread = target };
}

pub fn sleeping(launcher: *Kata) !types.Target {
    return child(launcher, park);
}

pub fn finished(launcher: *Kata) !types.Target {
    return child(launcher, finish);
}

pub fn faulted(launcher: *Kata) !types.Target {
    const owner = try kata.create.createFor(launcher);
    const identifier = owner.ID;
    errdefer dispose(identifier);
    try user.memory.allocate.allocate(owner, locations.CODE_BASE);
    try user.memory.allocate.allocate(owner, locations.STACK_BASE);
    try user.memory.allocate.allocate(owner, access.DATA_ADDRESS);
    var bytes = access.EXECUTE;
    std.mem.writeInt(u64, bytes[access.ADDRESS_OFFSET..][0..access.OPERAND_BYTES], access.DATA_ADDRESS, .little);
    try user.memory.load.load(owner, locations.CODE_BASE, &bytes);
    try user.memory.load.load(owner, access.DATA_ADDRESS, &access.RETURN);
    try user.memory.finalize.finalize(owner, locations.CODE_BASE, .ReadExecute);
    try user.memory.finalize.finalize(owner, locations.STACK_BASE, .ReadWrite);
    const target = try thread.user.create(owner, locations.CODE_BASE, locations.STACK_BASE, common.constants.memory.sizes.PAGE_SIZE, 0);
    const stack = target.User.RSP;
    try sensei.control.start(target);
    return .{ .ID = identifier, .Thread = target, .Stack = stack };
}

pub fn reclaimed(identifier: u64) !void {
    var attempts: usize = 0;
    while (attempts < limits.DRIVE_LIMIT) : (attempts += 1) {
        if (kata.completion.lifetime.peek(identifier) != null) return;
        try sensei.run.yield();
    }
    return error.DriveLimit;
}

fn never(_: ?*anyopaque) bool {
    return false;
}

fn park(_: ?*anyopaque) callconv(.{ .x86_64_sysv = .{} }) noreturn {
    sensei.wait.blockUntil(&parked, never, null) catch |failure| verify.failure(failure);
    unreachable;
}

fn finish(_: ?*anyopaque) callconv(.{ .x86_64_sysv = .{} }) noreturn {
    thread.finish.complete();
}

pub fn terminate(identifier: u64) !void {
    try kata.finish.terminate(kata.state.findByID(identifier).?, .{ .Exited = inputs.RESULT });
}

pub fn response(actor: *const Actor, step: usize, status: u64, value: u64) !bool {
    var result: values.InvocationResult = undefined;
    try copy.read(actor.Owner, std.mem.asBytes(&result), actor.Data + locations.RESULT_OFFSET + (step - 1) * @sizeOf(values.InvocationResult));
    return result.Status == status and result.Value == value;
}

pub fn record(actor: *const Actor) !types.Record {
    var result: types.Record = undefined;
    try copy.read(actor.Owner, std.mem.asBytes(&result), actor.Data + locations.OUTPUT_OFFSET);
    return result;
}

pub fn guarded(actor: *const Actor) !bool {
    var tail: [locations.OUTPUT_BYTES - inputs.RECORD_BYTES]u8 = undefined;
    try copy.read(actor.Owner, &tail, actor.Data + locations.OUTPUT_OFFSET + inputs.RECORD_BYTES);
    return std.mem.allEqual(u8, &tail, locations.GUARD_BYTE);
}

pub fn dispose(identifier: u64) void {
    const flags = guard.acquire();
    defer guard.release(flags);
    const current = thread.state.getCurrent().?.Owner.ID;
    if (kata.completion.storage.ownerOf(identifier)) |owner| {
        if (owner != current and owner != 0) kata.completion.storage.adopt(owner, current);
    }
    scheduling.dispose(identifier) catch |failure| verify.failure(failure);
}
