//! Real Requester, Granted Provisioner, And Staged Compiler ELF

const std = @import("std");

const completion = @import("tests").guest.mirai.invocations.completion.support;
const constants = @import("tests").guest.constants.postman;
const copy = @import("mirai").user.copy.transfer;
const elf = @import("shared").elf;
const harness = @import("tests").guest.mirai.postman.harness;
const inputs = @import("tests").guest.constants.completion;
const invocation = @import("mirai").invocations.types.postman.exchange;
const kata = @import("mirai").kata;
const kernel = @import("mirai").memory.allocator.native;
const labels = @import("tests").guest.strings.postman;
const launch = @import("mirai").launch;
const postmanwire = @import("tests").fixtures.constants.postman;
const types = @import("tests").guest.types.postman;
const user = @import("mirai").user;
const verify = @import("tests").guest.support.verify;

const Actor = types.Actor;
const Operation = types.Operation;
const IMAGE = @embedFile("provisionimage");

pub fn run() !void {
    var plan = try elf.validate.image.parse(kernel.get(), IMAGE, .{
        .MinimumAddress = constants.PAGE_BYTES,
        .MaximumAddress = @import("tests").fixtures.constants.elf.USER_END,
        .MaximumPages = 1,
    });
    defer plan.deinit();
    try harness.check(plan.Segments.len == 1 and plan.Entry == constants.CODE_BASE and plan.Ranges.len == 1);
    const segment = plan.Segments[0];
    try harness.check(segment.VirtualAddress == constants.CODE_BASE);
    const bytes = IMAGE[@intCast(segment.Offset)..][0..@intCast(segment.UnitSize)];

    var server = try harness.create();
    defer harness.dispose(server.ID);
    var client = try harness.create();
    defer harness.dispose(client.ID);
    try harness.check(launch.request.authority.grant(server.Owner));
    const source = server.Data + constants.PAGE_BYTES;
    try user.memory.allocate.allocate(server.Owner, source);
    try user.memory.load.load(server.Owner, source, bytes);
    try user.memory.finalize.finalize(server.Owner, source, .ReadOnly);
    try harness.input(&server, &constants.PROVISION_STARTUP);
    try installClient(&client, server.ID);
    try installServer(&server);
    try harness.start(&server);
    try harness.waitBlocked(&server);
    try harness.start(&client);
    try harness.waitStep(&server, 1);
    try harness.waitBlocked(&client);
    try harness.advance(&server, 2);
    try harness.waitStep(&server, 3);
    verify.require(try harness.resultIs(&server, 3, .Success, 0), labels.PROVISION_PAGE);
    const delivery = (try harness.record(&server)).Serving orelse return error.InvalidFixture;
    const draft = (launch.request.lease.transaction(delivery) orelse return error.InvalidFixture).Child orelse return error.InvalidFixture;

    try descriptor(&server, &.{ constants.CODE_BASE, constants.INVALID_ADDRESS, segment.UnitSize });
    try next(&server, 4);
    var first: [1]u8 = undefined;
    try copy.read(draft, &first, constants.CODE_BASE);
    verify.require(try harness.resultIs(&server, 4, .InvalidAddress, 0) and first[0] == 0, labels.PROVISION_COPY);
    try descriptor(&server, &.{ constants.CODE_BASE, source, segment.UnitSize });
    try harness.advance(&server, 8);
    try harness.waitStep(&server, 9);
    for (5..10) |step| try harness.check(try harness.resultIs(&server, step, .Success, 0));
    try descriptor(&server, &.{ constants.DATA_BASE, server.Data + constants.INPUT_OFFSET, constants.PROVISION_STARTUP.len });
    try next(&server, 10);
    try harness.check(try harness.resultIs(&server, 10, .Success, 0));
    try descriptor(&server, &.{ plan.Entry, constants.STACK_BASE, constants.PAGE_BYTES, constants.DATA_BASE });
    try next(&server, 11);
    const refused = try harness.resultIs(&server, 11, .InvalidState, 0) and draft.State == .Born and draft.ThreadCount == 0 and
        !kata.completion.storage.find(draft.ID).?.Published;
    try harness.advance(&server, 13);
    try harness.waitStep(&server, 14);
    const result = try started(&server, 13);
    try harness.check(result != 0);
    verify.require(refused and try harness.resultIs(&server, 12, .Success, 0) and
        try harness.resultIs(&server, 14, .InvalidState, 0) and kata.completion.storage.ownerOf(result) == client.ID, labels.PROVISION_PUBLISH);
    try next(&server, 15);
    const not_owner = try harness.resultIs(&server, 15, .NotOwner, 0);
    try harness.input(&server, std.mem.asBytes(&result));
    try next(&server, 16);
    try harness.waitStep(&client, 1);
    try harness.check(try harness.resultIs(&client, 1, .Success, @sizeOf(u64)));
    try next(&client, 2);
    const receipt = try completion.record(&client);
    const waited = try harness.resultIs(&client, 2, .Success, inputs.RECORD_BYTES) and receipt.Kind == inputs.EXITED and
        receipt.Result == constants.PROVISION_RESULT;
    try next(&client, 3);
    verify.require(not_owner and waited and try harness.resultIs(&client, 3, .Success, inputs.RECORD_BYTES) and
        kata.state.findByID(result) == null and kata.completion.storage.ownerOf(result) == null, labels.PROVISION_RESULT);
}

fn installClient(client: *Actor, destination: u64) !void {
    const call: invocation.Call = .{
        .Destination = destination,
        .Type = postmanwire.CALL_TYPE,
        .Request = client.Data + constants.INPUT_OFFSET,
        .RequestLength = constants.REQUEST.len,
        .Reply = client.Data + constants.TICKET_OFFSET,
        .ReplyCapacity = @sizeOf(u64),
        .Metadata = client.Data + constants.HEADER_OFFSET,
    };
    try copy.write(client.Owner, client.Data + constants.CALL_OFFSET, std.mem.asBytes(&call));
    var wait = completion.operation(client, inputs.WAIT);
    wait.First = .{ .Indirect = call.Reply };
    var collect = completion.operation(client, inputs.COLLECT);
    collect.First = wait.First;
    try harness.install(client, &.{ harness.call(client), wait, collect });
}

fn installServer(server: *Actor) !void {
    const descriptor_address = server.Data + constants.CALL_OFFSET;
    var collect = completion.operation(server, inputs.COLLECT);
    collect.First = .{ .Indirect = server.Data + constants.RESULT_OFFSET + 12 * @sizeOf(types.InvocationResult) + @sizeOf(u64) };
    var reply = harness.reply(server);
    reply.Third = @sizeOf(u64);
    try harness.install(server, &.{
        harness.receive(server, constants.OUTPUT_BYTES),                          operation(server, constants.PROVISION_BEGIN, 0, 0),
        operation(server, constants.PROVISION_ALLOCATE, constants.CODE_BASE, 0),  operation(server, constants.PROVISION_LOAD, descriptor_address, 0),
        operation(server, constants.PROVISION_LOAD, descriptor_address, 0),       operation(server, constants.PROVISION_SEAL, constants.CODE_BASE, constants.PROVISION_EXECUTE),
        operation(server, constants.PROVISION_ALLOCATE, constants.STACK_BASE, 0), operation(server, constants.PROVISION_SEAL, constants.STACK_BASE, constants.PROVISION_WRITE),
        operation(server, constants.PROVISION_ALLOCATE, constants.DATA_BASE, 0),  operation(server, constants.PROVISION_LOAD, descriptor_address, 0),
        operation(server, constants.PROVISION_START, descriptor_address, 0),      operation(server, constants.PROVISION_SEAL, constants.DATA_BASE, constants.PROVISION_READ),
        operation(server, constants.PROVISION_START, descriptor_address, 0),      operation(server, constants.PROVISION_START, descriptor_address, 0),
        collect,                                                                  reply,
    });
}

fn operation(actor: *const Actor, opcode: u64, argument: u64, protection: u64) Operation {
    return .{
        .Service = .Yield,
        .ServiceValue = constants.PROVISION_SERVICE,
        .First = .{ .Indirect = actor.Data + constants.HEADER_OFFSET + 3 * @sizeOf(u64) },
        .Second = opcode,
        .Third = argument,
        .LetterType = protection,
    };
}

fn descriptor(actor: *const Actor, fields: []const u64) !void {
    try copy.write(actor.Owner, actor.Data + constants.CALL_OFFSET, std.mem.sliceAsBytes(fields));
}

fn next(actor: *const Actor, step: u64) !void {
    try harness.advance(actor, step - 1);
    try harness.waitStep(actor, step);
}

fn started(actor: *const Actor, step: usize) !u64 {
    var result: types.InvocationResult = undefined;
    try copy.read(actor.Owner, std.mem.asBytes(&result), actor.Data + constants.RESULT_OFFSET + (step - 1) * @sizeOf(types.InvocationResult));
    try harness.check(result.Status == 0);
    return result.Value;
}
