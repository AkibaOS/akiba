//! Actual Requester And Serving Weaver Persona Launch Verification

const std = @import("std");

const abi = @import("mirai").invocations.types.postman.exchange;
const bootstrap = @import("mirai").bootstrap;
const completion = @import("tests").guest.mirai.invocations.completion.support;
const copy = @import("mirai").user.copy.transfer;
const elf = @import("shared").elf;
const fixtures = @import("tests").fixtures.constants.elf;
const harness = @import("tests").guest.mirai.postman.harness;
const inputs = @import("tests").fixtures.constants.weaver;
const kagami = @import("mirai").kagami;
const kata = @import("mirai").kata;
const kernel = @import("mirai").memory.allocator.native;
const labels = @import("tests").fixtures.strings.weaver;
const launch = @import("mirai").launch;
const locations = @import("tests").guest.constants.postman;
const outcome = @import("tests").guest.constants.completion;
const pmm = @import("mirai").pmm;
const postmanwire = @import("tests").fixtures.constants.postman;
const stage = @import("tests").guest.mirai.bootstrap.stage;
const thread = @import("mirai").thread;
const user = @import("mirai").user;
const verify = @import("tests").guest.support.verify;

const Actor = @import("tests").guest.types.postman.Actor;
const Operation = @import("tests").guest.types.postman.Operation;
const types = @import("tests").fixtures.types.weaver;

const IMAGE = @embedFile("weaverimage");
const LIBRARY = @embedFile("dynamiclibrary");

pub fn run() !void {
    const launcher = thread.state.getCurrent().?.Owner;
    const image = try bootstrap.image.prepare.prepare(launcher, IMAGE, .{ .StackBase = inputs.SERVER_STACK, .StackPages = inputs.SERVER_STACK_PAGES });
    defer harness.dispose(image.ID);
    try harness.check(image.Thread.Mode == .Persona and launch.request.authority.grant(image.Owner));
    _ = try bootstrap.image.start.start(image);
    const server: Actor = .{ .Owner = image.Owner, .ID = image.ID, .Code = 0, .Data = 0, .Stack = inputs.SERVER_STACK, .Target = image.Thread };
    try harness.waitBlocked(&server);
    try refuse(server.ID, .Missing);
    try refuse(server.ID, .RefuseLoad);
    try execute(server.ID);
    try exerciseCache(server.ID);
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

fn exerciseCache(server: u64) !void {
    var first = try harness.create();
    defer harness.dispose(first.ID);
    try install(&first, server, .Cached);
    const initial = try receive(&first);
    try harness.check(initial.State == .Started and initial.Child != 0 and initial.Retained != 0 and initial.Attached == 0);
    defer completion.dispose(initial.Child);

    var second = try harness.create();
    defer harness.dispose(second.ID);
    try install(&second, server, .Cached);
    const reused = try receive(&second);
    try harness.check(reused.State == .Started and reused.Child != 0);
    defer completion.dispose(reused.Child);
    const frame = try sharedCode(initial, reused);

    const bytes_refused = try checkMismatch(server, .Mismatch);
    const protection_refused = try checkMismatch(server, .ProtectionMismatch);
    verify.require(bytes_refused and protection_refused, labels.CACHE_REFUSE);
    var evictor = try harness.create();
    defer harness.dispose(evictor.ID);
    try install(&evictor, server, .Evict);
    const evicted = try receive(&evictor);
    verify.require(evicted.State == .Evicted and evicted.Child == 0 and evicted.Begins == 0 and pmm.state.isAllocated(frame) and
        user.state.ledger.ownsPhysical(frame), labels.CACHE_EVICT);

    const first_exited = try finishCached(&first, initial.Child);
    const retained = pmm.state.isAllocated(frame) and user.state.ledger.ownsPhysical(frame);
    const second_exited = try finishCached(&second, reused.Child);
    verify.require(first_exited and retained and second_exited and !pmm.state.isAllocated(frame) and
        !user.state.ledger.ownsPhysical(frame) and kata.state.findByID(server) != null, labels.CACHE_LAST);
}

fn sharedCode(initial: types.Receipt, reused: types.Receipt) !u64 {
    var library = try elf.validate.dynamic.parse(kernel.get(), LIBRARY, fixtures.DYNAMIC_LIBRARY_BIAS, .Library, .{
        .MinimumAddress = fixtures.PAGE_BYTES,
        .MaximumAddress = fixtures.USER_END,
        .MaximumPages = fixtures.MAXIMUM_PAGES,
    });
    defer library.Image.deinit();
    const code = try stage.codeAddress(&library);
    const data = try stage.counterAddress(&library);
    const first = kata.state.findByID(initial.Child) orelse return error.InvalidFixture;
    const second = kata.state.findByID(reused.Child) orelse return error.InvalidFixture;
    const first_code = kagami.extract.lookup(first.AddressSpace.?, code) orelse return error.InvalidFixture;
    const second_code = kagami.extract.lookup(second.AddressSpace.?, code) orelse return error.InvalidFixture;
    const first_data = kagami.extract.lookup(first.AddressSpace.?, data) orelse return error.InvalidFixture;
    const second_data = kagami.extract.lookup(second.AddressSpace.?, data) orelse return error.InvalidFixture;
    verify.require(reused.Retained == 0 and reused.Attached == initial.Retained and reused.Allocations + reused.Attached == initial.Allocations and
        first_code.PhysicalAddress == second_code.PhysicalAddress and second_code.Executable and !second_code.Writable and
        first_data.PhysicalAddress != second_data.PhysicalAddress and first_data.Writable and second_data.Writable, labels.CACHE_REUSE);
    return first_code.PhysicalAddress;
}

fn checkMismatch(server: u64, mode: types.Mode) !bool {
    var client = try harness.create();
    defer harness.dispose(client.ID);
    try install(&client, server, mode);
    const before = user.state.ledger.count();
    const katas = kataCount();
    const result = try receive(&client);
    return user.state.ledger.count() == before and kataCount() == katas and result.Child == 0 and
        result.State == .Refused and result.Begins == 1 and result.Aborts == 1 and result.Attached == 0 and result.RejectedStatus == inputs.INVALID_ARGUMENT;
}

fn finishCached(client: *const Actor, child: u64) !bool {
    try harness.advance(client, 3);
    try harness.waitStep(client, 4);
    const receipt = try completion.record(client);
    return try harness.resultIs(client, 2, .Success, 0) and try harness.resultIs(client, 3, .Success, outcome.RECORD_BYTES) and
        try harness.resultIs(client, 4, .Success, outcome.RECORD_BYTES) and receipt.Kind == outcome.EXITED and
        receipt.Result == inputs.EXPECTED_RESULT and kata.state.findByID(child) == null and kata.completion.storage.ownerOf(child) == null;
}

fn install(client: *Actor, server: u64, mode: types.Mode) !void {
    try harness.input(client, &.{@intFromEnum(mode)});
    const descriptor: abi.Call = .{
        .Destination = server,
        .Type = postmanwire.CALL_TYPE,
        .Request = client.Data + locations.INPUT_OFFSET,
        .RequestLength = 1,
        .Reply = client.Data + locations.TICKET_OFFSET,
        .ReplyCapacity = @sizeOf(types.Receipt),
        .Metadata = client.Data + locations.HEADER_OFFSET,
    };
    try copy.write(client.Owner, client.Data + locations.CALL_OFFSET, std.mem.asBytes(&descriptor));
    if (mode != .Launch and mode != .Cached) return harness.install(client, &.{harness.call(client)});
    var wait = completion.operation(client, outcome.WAIT);
    wait.First = .{ .Indirect = descriptor.Reply };
    var collect = completion.operation(client, outcome.COLLECT);
    collect.First = wait.First;
    if (mode == .Cached) {
        const release: Operation = .{ .Service = .Send, .First = wait.First, .LetterType = inputs.RELEASE_TYPE };
        return harness.install(client, &.{ harness.call(client), release, wait, collect });
    }
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
