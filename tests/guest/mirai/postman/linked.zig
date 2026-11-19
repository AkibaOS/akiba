//! Actual Requester And Serving Weaver Persona Launch Verification

const std = @import("std");

const abi = @import("mirai").invocations.types.postman;
const bootstrap = @import("mirai").bootstrap;
const completion = @import("tests").guest.mirai.invocations.completion.support;
const copy = @import("mirai").user.copy.transfer;
const harness = @import("tests").guest.mirai.postman.harness;
const inputs = @import("tests").constants.weaver;
const kata = @import("mirai").kata;
const labels = @import("tests").strings.weaver;
const launch = @import("mirai").launch;
const locations = @import("tests").constants.postman;
const outcome = @import("tests").constants.completion;
const thread = @import("mirai").thread;
const user = @import("mirai").user;
const verify = @import("tests").verify;

const Actor = @import("tests").types.postman.Actor;
const types = @import("tests").types.weaver;

const IMAGE = @embedFile("weaverimage");

pub fn run() !void {
    const launcher = thread.state.getCurrent().?.Owner;
    const image = try bootstrap.image.prepare.prepare(launcher, IMAGE, .{ .StackBase = inputs.SERVER_STACK, .StackPages = inputs.SERVER_STACK_PAGES });
    defer harness.dispose(image.ID);
    try harness.check(image.Thread.Mode == .Persona and launch.authority.grant(image.Owner));
    _ = try bootstrap.image.start.start(image);
    const server: Actor = .{ .Owner = image.Owner, .ID = image.ID, .Code = 0, .Data = 0, .Stack = inputs.SERVER_STACK, .Target = image.Thread };
    try harness.waitBlocked(&server);
    try refuse(server.ID, .Missing);
    try refuse(server.ID, .RefuseLoad);
    try execute(server.ID);
}

fn refuse(server: u64, comptime mode: types.Mode) !void {
    var client = try harness.create();
    defer harness.dispose(client.ID);
    try install(&client, server, mode);
    const before = user.state.ledger.count();
    const katas = kataCount();
    const result = try receive(&client);
    const cleanup = user.state.ledger.count() == before and kataCount() == katas and result.Child == 0;
    if (mode == .Missing) {
        verify.require(cleanup and result.State == .MissingLibrary and result.Begins == 0 and result.Allocations == 0 and result.Aborts == 0, labels.MISSING);
    } else {
        verify.require(cleanup and result.State == .Refused and result.Begins == 1 and result.Allocations == 2 and result.Aborts == 1 and
            result.RejectedStatus == inputs.INVALID_ADDRESS, labels.ROLLBACK);
    }
}

fn execute(server: u64) !void {
    var client = try harness.create();
    defer harness.dispose(client.ID);
    try install(&client, server, .Launch);
    const result = try receive(&client);
    const child = result.Child;
    defer if (child != 0) completion.dispose(child);
    verify.require(result.State == .Started and child != 0 and result.Begins == 1 and result.Allocations > 2 and result.Aborts == 0 and
        kata.completion.storage.ownerOf(child) == client.ID, labels.OWNERSHIP);
    try harness.advance(&client, 1);
    try harness.waitStep(&client, 2);
    const receipt = try completion.record(&client);
    const waited = try harness.resultIs(&client, 2, .Success, outcome.RECORD_BYTES) and receipt.Kind == outcome.EXITED and receipt.Result == inputs.EXPECTED_RESULT;
    try harness.advance(&client, 2);
    try harness.waitStep(&client, 3);
    const collected = try completion.record(&client);
    verify.require(waited and try harness.resultIs(&client, 3, .Success, outcome.RECORD_BYTES) and
        std.meta.eql(receipt, collected) and kata.state.findByID(child) == null and kata.completion.storage.ownerOf(child) == null and
        try completion.guarded(&client), labels.EXECUTION);
}

fn install(client: *Actor, server: u64, mode: types.Mode) !void {
    try harness.input(client, &.{@intFromEnum(mode)});
    const descriptor: abi.Call = .{
        .Destination = server,
        .Type = locations.CALL_TYPE,
        .Request = client.Data + locations.INPUT_OFFSET,
        .RequestLength = 1,
        .Reply = client.Data + locations.TICKET_OFFSET,
        .ReplyCapacity = @sizeOf(types.Receipt),
        .Metadata = client.Data + locations.HEADER_OFFSET,
    };
    try copy.write(client.Owner, client.Data + locations.CALL_OFFSET, std.mem.asBytes(&descriptor));
    if (mode != .Launch) return harness.install(client, &.{harness.call(client)});
    var wait = completion.operation(client, outcome.WAIT);
    wait.First = .{ .Indirect = descriptor.Reply };
    var collect = completion.operation(client, outcome.COLLECT);
    collect.First = wait.First;
    try harness.install(client, &.{ harness.call(client), wait, collect });
}

fn receive(client: *const Actor) !types.Receipt {
    try harness.start(client);
    try harness.waitStep(client, 1);
    try harness.check(try harness.resultIs(client, 1, .Success, @sizeOf(types.Receipt)));
    var receipt: types.Receipt = undefined;
    try copy.read(client.Owner, std.mem.asBytes(&receipt), client.Data + locations.TICKET_OFFSET);
    return receipt;
}

fn kataCount() usize {
    var count: usize = 0;
    var owner = kata.state.first();
    while (owner) |current| : (owner = kata.state.next(current)) count += 1;
    return count;
}
