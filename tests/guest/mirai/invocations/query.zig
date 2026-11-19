//! Actual Persona Returning Invocation Checks

const std = @import("std");

const common = @import("common");
const drive = @import("tests").guest.support.drive;
const harness = @import("tests").guest.mirai.postman.harness;
const inputs = @import("tests").guest.constants.invocations;
const kata = @import("mirai").kata;
const labels = @import("tests").guest.strings.invocations;
const program = @import("tests").guest.mirai.postman.program;
const sensei = @import("mirai").sensei;
const thread = @import("mirai").thread;
const user = @import("mirai").user;
const verify = @import("tests").guest.support.verify;

var completed: bool = false;

pub fn run() !void {
    completed = false;
    const owner = try kata.create.create();
    const identifier = owner.ID;
    defer harness.dispose(identifier);
    try sensei.control.start(try thread.create.create(owner, entry, null));
    drive.run();
    const outcome = try kata.completion.lifetime.collect(identifier);
    verify.require(completed and outcome == .Completed and kata.state.findByID(identifier) == null, labels.CLEANUP);
}

fn entry(_: ?*anyopaque) callconv(.{ .x86_64_sysv = .{} }) noreturn {
    scenarios() catch |failure| verify.failure(failure);
    completed = true;
    thread.finish.complete();
}

fn scenarios() !void {
    var actor = try harness.create();
    defer harness.dispose(actor.ID);
    try harness.install(&actor, &.{
        .{ .Service = .Query, .First = .{ .Immediate = inputs.QUERY_ABI_SELECTOR } },
        .{ .Service = .Query, .First = .{ .Immediate = inputs.QUERY_KATA_SELECTOR } },
        .{ .Service = .Query, .First = .{ .Immediate = inputs.QUERY_INVALID_SELECTOR } },
        .{ .Service = .Yield },
    });
    try harness.start(&actor);
    try harness.waitStep(&actor, 1);
    verify.require(try harness.resultIs(&actor, 1, .Success, inputs.ABI_VERSION), labels.QUERY_ABI);
    try harness.advance(&actor, 1);
    try harness.waitStep(&actor, 2);
    verify.require(try harness.resultIs(&actor, 2, .Success, actor.ID), labels.QUERY_KATA);
    try harness.advance(&actor, 2);
    try harness.waitStep(&actor, 3);
    verify.require(try harness.resultIs(&actor, 3, .InvalidArgument, 0), labels.QUERY_INVALID);
    try harness.advance(&actor, 3);
    try harness.waitStep(&actor, 4);
    verify.require(try harness.resultIs(&actor, 4, .Success, 0), labels.YIELD);
    try unsupported();
}

fn unsupported() !void {
    var actor = try harness.create();
    defer harness.dispose(actor.ID);
    var encoded = try program.encode(&actor, &.{.{ .Service = .Query }});
    std.mem.writeInt(u64, encoded.Bytes[inputs.SERVICE_OPERAND_OFFSET..][0..@sizeOf(u64)], inputs.UNKNOWN_SERVICE, .little);
    try user.memory.load.load(actor.Owner, actor.Code, encoded.Bytes[0..encoded.Length]);
    try user.memory.finalize.finalize(actor.Owner, actor.Code, .ReadExecute);
    actor.Target = try thread.user.create(actor.Owner, actor.Code, actor.Stack, common.constants.memory.sizes.PAGE_SIZE, 0);
    try harness.start(&actor);
    try harness.waitStep(&actor, 1);
    verify.require((try harness.resultIs(&actor, 1, .Unsupported, 0)) and actor.Owner.State == .Alive, labels.UNSUPPORTED);
}
