//! Completion Output And Target Rejection Without Consumption

const std = @import("std");

const copy = @import("mirai").user.copy.transfer;
const harness = @import("tests").guest.postman.harness;
const inputs = @import("tests").guest.constants.completion.outcomes;
const kata = @import("mirai").kata;
const labels = @import("tests").guest.strings.completion.witnesses;
const locations = @import("tests").guest.constants.postman.transport;
const support = @import("tests").guest.completion.support;
const types = @import("tests").guest.types.completion.outcomes;
const verify = @import("tests").guest.support.verify;

pub fn run() !void {
    var actor = try harness.create();
    defer harness.dispose(actor.ID);
    const born = try kata.create.create();
    const born_id = born.ID;
    defer support.dispose(born_id);
    var short = support.operation(&actor, inputs.OBSERVE);
    short.Third = inputs.RECORD_BYTES - 1;
    var missing = support.operation(&actor, inputs.WAIT);
    missing.Second = locations.INVALID_ADDRESS;
    var readonly = support.operation(&actor, inputs.COLLECT);
    readonly.Second = actor.Code;
    var short_collect = support.operation(&actor, inputs.COLLECT);
    short_collect.Third = inputs.RECORD_BYTES - 1;
    var unknown = support.operation(&actor, inputs.OBSERVE);
    unknown.First = .{ .Immediate = inputs.UNKNOWN_ID };
    var unpublished = support.operation(&actor, inputs.WAIT);
    unpublished.First = .{ .Indirect = actor.Data + locations.CALL_OFFSET };
    var self = support.operation(&actor, inputs.WAIT);
    self.First = .{ .Immediate = actor.ID };
    var missing_collect = support.operation(&actor, inputs.COLLECT);
    missing_collect.Second = locations.INVALID_ADDRESS;
    var collect = support.operation(&actor, inputs.COLLECT);
    collect.Third = std.math.maxInt(u64);
    try harness.install(&actor, &.{ .{ .Service = .Yield }, short, missing, readonly, short_collect, unknown, unpublished, self, missing_collect, collect });
    try harness.start(&actor);
    try harness.waitStep(&actor, 1);
    const target = try support.sleeping(actor.Owner);
    defer support.dispose(target.ID);
    try support.terminate(target.ID);
    try support.identify(&actor, target.ID);
    try copy.write(actor.Owner, actor.Data + locations.CALL_OFFSET, std.mem.asBytes(&born_id));
    var correct = true;
    for (2..10) |step| {
        try harness.advance(&actor, step - 1);
        try harness.waitStep(&actor, step);
        const small = step == 2 or step == 5;
        const invalid_target = step >= 6 and step <= 8;
        const status = if (small) inputs.BUFFER_TOO_SMALL else if (invalid_target) inputs.INVALID_TARGET else inputs.INVALID_ADDRESS;
        const record = try kata.completion.lifetime.borrow(target.ID);
        correct = correct and (try support.response(&actor, step, status, if (small) inputs.RECORD_BYTES else 0)) and
            (try harness.untouched(&actor)) and record.Reclaimed and !record.Collected and record.OwnerID == actor.ID and
            record.Observers == 1 and record.Waiters.Count == 0;
        kata.completion.lifetime.drop(target.ID);
    }
    verify.require(correct, labels.BOUNDS);
    verify.require(correct and born.State == .Born, labels.TARGETS);
    try harness.advance(&actor, 9);
    try harness.waitStep(&actor, 10);
    const expected: types.Record = .{ .Kind = inputs.EXITED, .Result = inputs.RESULT };
    verify.require((try support.response(&actor, 10, inputs.SUCCESS, inputs.RECORD_BYTES)) and
        std.meta.eql(expected, try support.record(&actor)) and (try support.guarded(&actor)) and
        kata.completion.storage.ownerOf(target.ID) == null, labels.EXITED);
}
