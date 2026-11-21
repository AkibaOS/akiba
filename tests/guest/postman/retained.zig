//! Sealed Backing Handles Through Real Provision Requests

const std = @import("std");

const completion = @import("tests").guest.completion.support;
const constants = @import("tests").guest.constants.postman.transport;
const copy = @import("mirai").user.copy.transfer;
const elf = @import("shared").elf;
const fixtures = @import("tests").fixtures.constants.elf.layout;
const harness = @import("tests").guest.postman.harness;
const invocation = @import("shared").persona.types.call;
const kagami = @import("mirai").kagami;
const kata = @import("mirai").kata;
const kernel = @import("mirai").memory.allocator.native;
const labels = @import("tests").guest.strings.postman.witnesses;
const launch = @import("mirai").launch;
const outcomes = @import("tests").guest.constants.completion.outcomes;
const pmm = @import("mirai").pmm;
const postmanwire = @import("tests").fixtures.constants.postman;
const types = @import("tests").guest.types.postman.fixtures;
const user = @import("mirai").user;
const verify = @import("tests").guest.support.verify;

const Actor = types.Actor;
const Operation = types.Operation;
const IMAGE = @embedFile("provisionimage");

pub fn run() !void {
    try verifyAborted();
    try verifyPublished();
}

fn verifyAborted() !void {
    var server = try harness.create();
    defer harness.dispose(server.ID);
    var client = try harness.create();
    defer harness.dispose(client.ID);
    try harness.check(launch.request.authority.grant(server.Owner));
    const descriptor = server.Data + constants.CALL_OFFSET;
    try beginCall(&server, &client, &.{
        harness.receive(&server, constants.OUTPUT_BYTES),
        operation(&server, constants.PROVISION_BEGIN, 0, 0),
        operation(&server, constants.PROVISION_ALLOCATE, constants.CODE_BASE, 0),
        operation(&server, constants.PROVISION_RETAIN, constants.CODE_BASE, 0),
        operation(&server, constants.PROVISION_SEAL, constants.CODE_BASE, constants.PROVISION_READ),
        operation(&server, constants.PROVISION_RETAIN, constants.CODE_BASE, 0),
        operation(&server, constants.PROVISION_ATTACH, descriptor, 0),
        operation(&server, constants.PROVISION_ABORT, 0, 0),
        operation(&server, constants.PROVISION_BEGIN, 0, 0),
        operation(&server, constants.PROVISION_ATTACH, descriptor, 0),
        operation(&server, constants.PROVISION_ABORT, 0, 0),
    }, false);
    const baseline = user.state.ledger.count();
    try advance(&server, 6);
    const retained = try result(&server, 6);
    const draft = try child(&server);
    const id = draft.ID;
    const frame = kagami.extract.extract(draft.AddressSpace.?, constants.CODE_BASE) orelse return error.InvalidFixture;
    try fields(&server, &.{ retained.Value, constants.DATA_BASE });
    try advance(&server, 7);
    verify.require(try harness.resultIs(&server, 4, .InvalidState, 0) and retained.Status == 0 and retained.Value != 0 and
        try harness.resultIs(&server, 7, .InvalidTarget, 0), labels.RETAIN_PENDING);
    try advance(&server, 8);
    const reclaimed = try harness.resultIs(&server, 8, .Success, 0) and kata.state.findByID(id) == null and !pmm.state.isAllocated(frame) and
        !user.state.ledger.ownsPhysical(frame) and user.state.ledger.count() == baseline;
    try advance(&server, 10);
    const stale = try harness.resultIs(&server, 9, .Success, 0) and try harness.resultIs(&server, 10, .InvalidTarget, 0);
    try advance(&server, 11);
    verify.require(reclaimed and stale and try harness.resultIs(&server, 11, .Success, 0), labels.RETAIN_ABORT);
}

fn verifyPublished() !void {
    var issuer = try harness.create();
    var issuer_live = true;
    defer if (issuer_live) harness.dispose(issuer.ID);
    var later = try harness.sibling(&issuer, 1);
    try harness.check(launch.request.authority.grant(issuer.Owner));
    const retained = try publish(&issuer);

    var foreign = try harness.create();
    defer harness.dispose(foreign.ID);
    try harness.check(launch.request.authority.grant(foreign.Owner));
    try checkAttach(&foreign, retained[0], retained[1], false);
    try checkAttach(&later, retained[0], retained[1], true);
    try harness.check(pmm.state.isAllocated(retained[1]));
    harness.dispose(issuer.ID);
    issuer_live = false;
    verify.require(!pmm.state.isAllocated(retained[1]) and !user.state.ledger.ownsPhysical(retained[1]), labels.RETAIN_CLEANUP);
}

fn publish(server: *Actor) ![2]u64 {
    var image = try elf.validate.image.parse(kernel.get(), IMAGE, .{
        .MinimumAddress = constants.PAGE_BYTES,
        .MaximumAddress = fixtures.USER_END,
        .MaximumPages = 1,
    });
    defer image.deinit();
    try harness.check(image.Segments.len == 1 and image.Entry == constants.CODE_BASE);
    const segment = image.Segments[0];
    const bytes = IMAGE[@intCast(segment.Offset)..][0..@intCast(segment.UnitSize)];
    const payload = server.Data + 3 * constants.PAGE_BYTES;
    try user.memory.allocate.allocate(server.Owner, payload);
    try user.memory.load.load(server.Owner, payload, bytes);
    try user.memory.finalize.finalize(server.Owner, payload, .ReadOnly);
    try harness.input(server, &constants.PROVISION_STARTUP);

    var client = try harness.create();
    defer harness.dispose(client.ID);
    const descriptor = server.Data + constants.CALL_OFFSET;
    var reply = harness.reply(server);
    reply.Third = @sizeOf(u64);
    try beginCall(server, &client, &.{
        harness.receive(server, constants.OUTPUT_BYTES),
        operation(server, constants.PROVISION_BEGIN, 0, 0),
        operation(server, constants.PROVISION_ALLOCATE, constants.CODE_BASE, 0),
        operation(server, constants.PROVISION_LOAD, descriptor, 0),
        operation(server, constants.PROVISION_SEAL, constants.CODE_BASE, constants.PROVISION_EXECUTE),
        operation(server, constants.PROVISION_RETAIN, constants.CODE_BASE, 0),
        operation(server, constants.PROVISION_ALLOCATE, constants.STACK_BASE, 0),
        operation(server, constants.PROVISION_SEAL, constants.STACK_BASE, constants.PROVISION_WRITE),
        operation(server, constants.PROVISION_ALLOCATE, constants.DATA_BASE, 0),
        operation(server, constants.PROVISION_LOAD, descriptor, 0),
        operation(server, constants.PROVISION_SEAL, constants.DATA_BASE, constants.PROVISION_READ),
        operation(server, constants.PROVISION_START, descriptor, 0),
        reply,
    }, true);
    try fields(server, &.{ constants.CODE_BASE, payload, bytes.len });
    try advance(server, 9);
    const draft = try child(server);
    const frame = kagami.extract.extract(draft.AddressSpace.?, constants.CODE_BASE) orelse return error.InvalidFixture;
    const retained = try result(server, 6);
    try harness.check(retained.Status == 0 and retained.Value != 0);
    try fields(server, &.{ constants.DATA_BASE, server.Data + constants.INPUT_OFFSET, constants.PROVISION_STARTUP.len });
    try advance(server, 11);
    try fields(server, &.{ image.Entry, constants.STACK_BASE, constants.PAGE_BYTES, constants.DATA_BASE });
    try advance(server, 12);
    const launched = try result(server, 12);
    try harness.check(launched.Status == 0 and launched.Value != 0);
    defer completion.dispose(launched.Value);
    try harness.input(server, std.mem.asBytes(&launched.Value));
    try advance(server, 13);
    try harness.waitStep(&client, 1);
    try harness.advance(&client, 2);
    try harness.waitStep(&client, 3);
    const receipt = try completion.record(&client);
    try harness.check(try harness.resultIs(&client, 3, .Success, outcomes.RECORD_BYTES));
    try harness.check(receipt.Kind == outcomes.EXITED and receipt.Result == constants.PROVISION_RESULT and kata.state.findByID(launched.Value) == null and pmm.state.isAllocated(frame));
    return .{ retained.Value, frame };
}

fn checkAttach(server: *Actor, handle: u64, frame: u64, comptime allowed: bool) !void {
    var client = try harness.create();
    defer harness.dispose(client.ID);
    try fields(server, &.{ handle, constants.CODE_BASE });
    try beginCall(server, &client, &.{
        harness.receive(server, constants.OUTPUT_BYTES),
        operation(server, constants.PROVISION_BEGIN, 0, 0),
        operation(server, constants.PROVISION_ATTACH, server.Data + constants.CALL_OFFSET, 0),
        operation(server, constants.PROVISION_ABORT, 0, 0),
    }, false);
    try advance(server, 3);
    const draft = try child(server);
    const mapping = kagami.extract.lookup(draft.AddressSpace.?, constants.CODE_BASE);
    if (allowed) {
        verify.require(try harness.resultIs(server, 3, .Success, 0) and mapping != null and mapping.?.PhysicalAddress == frame and
            mapping.?.Executable and !mapping.?.Writable, labels.RETAIN_ATTACH);
    } else {
        verify.require(try harness.resultIs(server, 3, .InvalidTarget, 0) and mapping == null, labels.RETAIN_FOREIGN);
    }
    try advance(server, 4);
    try harness.check(try harness.resultIs(server, 4, .Success, 0));
}

fn beginCall(server: *Actor, client: *Actor, operations: []const Operation, collect: bool) !void {
    const descriptor: invocation.Call = .{
        .Destination = server.ID,
        .Type = postmanwire.CALL_TYPE,
        .Request = client.Data + constants.INPUT_OFFSET,
        .RequestLength = constants.REQUEST.len,
        .Reply = client.Data + constants.TICKET_OFFSET,
        .ReplyCapacity = @sizeOf(u64),
        .Metadata = client.Data + constants.HEADER_OFFSET,
    };
    try copy.write(client.Owner, client.Data + constants.CALL_OFFSET, std.mem.asBytes(&descriptor));
    var wait = completion.operation(client, outcomes.WAIT);
    wait.First = .{ .Indirect = descriptor.Reply };
    var collect_result = completion.operation(client, outcomes.COLLECT);
    collect_result.First = wait.First;
    try harness.install(client, if (collect) &.{ harness.call(client), wait, collect_result } else &.{harness.call(client)});
    try harness.install(server, operations);
    try harness.start(server);
    try harness.waitBlocked(server);
    try harness.start(client);
    try harness.waitStep(server, 1);
    try harness.waitBlocked(client);
}

fn operation(server: *const Actor, command: u64, argument: u64, protection: u64) Operation {
    return .{
        .Service = .Yield,
        .ServiceValue = constants.PROVISION_SERVICE,
        .First = .{ .Indirect = server.Data + constants.HEADER_OFFSET + 3 * @sizeOf(u64) },
        .Second = command,
        .Third = argument,
        .LetterType = protection,
    };
}

fn child(server: *const Actor) !*kata.types.kata.Kata {
    const envelope = (try harness.record(server)).Serving orelse return error.InvalidFixture;
    const draft = launch.request.lease.transaction(envelope) orelse return error.InvalidFixture;
    return draft.Child orelse error.InvalidFixture;
}

fn fields(server: *const Actor, values: []const u64) !void {
    try copy.write(server.Owner, server.Data + constants.CALL_OFFSET, std.mem.sliceAsBytes(values));
}

fn advance(server: *const Actor, step: u64) !void {
    try harness.advance(server, step - 1);
    try harness.waitStep(server, step);
}

fn result(server: *const Actor, step: usize) !types.InvocationResult {
    var value: types.InvocationResult = undefined;
    try copy.read(server.Owner, std.mem.asBytes(&value), server.Data + constants.RESULT_OFFSET + (step - 1) * @sizeOf(types.InvocationResult));
    return value;
}
