//! Real Persona Request Ownership For Unpublished Launches

const constants = @import("tests").guest.constants.postman.transport;
const harness = @import("tests").guest.postman.harness;
const kata = @import("mirai").kata;
const labels = @import("tests").guest.strings.postman.witnesses;
const mirai = @import("mirai");
const types = @import("tests").guest.types.postman.fixtures;
const user = @import("mirai").user;
const verify = @import("tests").guest.support.verify;

const Actor = types.Actor;
const Kata = kata.types.kata.Kata;
const Operation = types.Operation;

pub fn run() !void {
    try abortAndReply();
    try requesterGone();
}

fn abortAndReply() !void {
    var server = try harness.create();
    defer harness.dispose(server.ID);
    var client = try harness.create();
    defer harness.dispose(client.ID);
    grant(&server);
    try harness.descriptor(&client, server.ID, constants.OUTPUT_BYTES);
    try harness.input(&server, &constants.REPLY);
    try harness.install(&client, &.{ command(&client, constants.PROVISION_BEGIN, false), harness.call(&client) });
    try harness.install(&server, &.{
        harness.receive(&server, constants.OUTPUT_BYTES),  command(&server, constants.PROVISION_BEGIN, false),
        command(&server, constants.PROVISION_BEGIN, true), command(&server, constants.PROVISION_BEGIN, true),
        command(&server, constants.PROVISION_ABORT, true), command(&server, constants.PROVISION_BEGIN, true),
        harness.reply(&server),
    });
    try harness.start(&server);
    try harness.waitBlocked(&server);
    try harness.start(&client);
    try harness.waitStep(&client, 1);
    try harness.advance(&client, 1);
    try harness.waitStep(&server, 1);
    try harness.waitBlocked(&client);
    try harness.advance(&server, 2);
    try harness.waitStep(&server, 3);
    const candidate = draft(&server);
    const owned = if (candidate) |child| child.State == .Born and child.ThreadCount == 0 and
        kata.completion.storage.ownerOf(child.ID) == client.ID and !kata.completion.storage.find(child.ID).?.Published else false;
    verify.require(owned and try harness.resultIs(&client, 1, .InvalidCaller, 0) and
        try harness.resultIs(&server, 2, .InvalidReply, 0) and try harness.resultIs(&server, 3, .Success, 0), labels.PROVISION_REQUESTER);
    const first = candidate.?.ID;
    var sibling = try harness.sibling(&server, 1);
    var stolen = command(&sibling, constants.PROVISION_BEGIN, false);
    stolen.First = .{ .Immediate = (try harness.header(&server)).ReplyTicket };
    try harness.install(&sibling, &.{stolen});
    try harness.start(&sibling);
    try harness.waitStep(&sibling, 1);
    verify.require(try harness.resultIs(&sibling, 1, .InvalidReply, 0) and draft(&server) == candidate, labels.PROVISION_THREAD);
    try next(&server, 4);
    verify.require(try harness.resultIs(&server, 4, .Busy, 0) and draft(&server) == candidate, labels.PROVISION_DUPLICATE);
    try next(&server, 5);
    const aborted = try harness.resultIs(&server, 5, .Success, 0) and gone(first) and draft(&server) == null;
    try next(&server, 6);
    const second = (draft(&server) orelse return error.InvalidFixture).ID;
    try next(&server, 7);
    try harness.waitStep(&client, 2);
    verify.require(aborted and second != first and gone(second) and draft(&server) == null and
        try harness.resultIs(&server, 6, .Success, 0) and try harness.resultIs(&server, 7, .Success, 0) and
        try harness.resultIs(&client, 2, .Success, constants.REPLY.len), labels.PROVISION_DISCARD);
}

fn requesterGone() !void {
    var server = try harness.create();
    defer harness.dispose(server.ID);
    var client = try harness.create();
    defer harness.dispose(client.ID);
    grant(&server);
    try harness.descriptor(&client, server.ID, constants.OUTPUT_BYTES);
    try harness.install(&client, &.{harness.call(&client)});
    var allocate = command(&server, constants.PROVISION_ALLOCATE, true);
    allocate.Third = constants.DATA_BASE;
    try harness.install(&server, &.{
        harness.receive(&server, constants.OUTPUT_BYTES), command(&server, constants.PROVISION_BEGIN, true),
        allocate,                                         command(&server, constants.PROVISION_BEGIN, true),
    });
    try harness.start(&server);
    try harness.waitBlocked(&server);
    try harness.start(&client);
    try harness.waitStep(&server, 1);
    try harness.waitBlocked(&client);
    try harness.advance(&server, 2);
    try harness.waitStep(&server, 3);
    const owner = draft(&server) orelse return error.InvalidFixture;
    const child = owner.ID;
    const allocated = try harness.resultIs(&server, 3, .Success, 0) and
        owner.AddressSpace.?.ResidentPages == 1 and user.state.ledger.find(owner, constants.DATA_BASE) != null;
    const before = user.state.ledger.count();
    const client_pages: usize = @intCast(client.Owner.AddressSpace.?.ResidentPages);
    harness.dispose(client.ID);
    try next(&server, 4);
    verify.require(allocated and gone(child) and draft(&server) == null and try harness.resultIs(&server, 4, .PeerGone, 0) and
        before > client_pages and user.state.ledger.count() == before - client_pages - 1, labels.PROVISION_DISCONNECT);
}

fn grant(actor: *const Actor) void {
    verify.require(mirai.launch.request.authority.grant(actor.Owner), labels.PROVISION_GRANT);
}

fn command(actor: *const Actor, opcode: u64, delivered: bool) Operation {
    return .{
        .Service = .Yield,
        .ServiceValue = constants.PROVISION_SERVICE,
        .First = if (delivered) .{ .Indirect = actor.Data + constants.HEADER_OFFSET + 3 * @sizeOf(u64) } else .{ .Immediate = 0 },
        .Second = opcode,
    };
}

fn draft(actor: *const Actor) ?*Kata {
    const record = harness.record(actor) catch return null;
    const delivery = record.Serving orelse return null;
    const transaction = mirai.launch.request.lease.transaction(delivery) orelse return null;
    return transaction.Child;
}

fn next(actor: *const Actor, step: u64) !void {
    try harness.advance(actor, step - 1);
    try harness.waitStep(actor, step);
}

fn gone(id: u64) bool {
    return kata.state.findByID(id) == null and kata.completion.storage.ownerOf(id) == null;
}
