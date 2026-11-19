//! Actual Persona Completion Observation And Collection

const std = @import("std");

const access = @import("tests").constants.access;
const harness = @import("tests").guest.mirai.postman.harness;
const inputs = @import("tests").constants.completion;
const kata = @import("mirai").kata;
const labels = @import("tests").strings.completion;
const support = @import("tests").guest.mirai.invocations.completion.support;
const types = @import("tests").types.completion;
const verify = @import("tests").guest.support.verify;

pub fn run() !void {
    try live();
    try terminal(inputs.COMPLETED);
    try terminal(inputs.EXITED);
    try terminal(inputs.FAULTED);
}

fn live() !void {
    var actor = try harness.create();
    defer harness.dispose(actor.ID);
    try harness.install(&actor, &.{ .{ .Service = .Yield }, support.operation(&actor, inputs.OBSERVE), support.operation(&actor, inputs.COLLECT) });
    try harness.start(&actor);
    try harness.waitStep(&actor, 1);
    const target = try support.sleeping(actor.Owner);
    defer support.dispose(target.ID);
    try support.identify(&actor, target.ID);
    try harness.advance(&actor, 1);
    try harness.waitStep(&actor, 2);
    const observed = try support.response(&actor, 2, inputs.WOULD_BLOCK, 0);
    try harness.advance(&actor, 2);
    try harness.waitStep(&actor, 3);
    verify.require(observed and (try support.response(&actor, 3, inputs.WOULD_BLOCK, 0)) and (try harness.untouched(&actor)), labels.LIVE);
}

fn terminal(comptime kind: u64) !void {
    var actor = try harness.create();
    defer harness.dispose(actor.ID);
    try harness.install(&actor, &.{ .{ .Service = .Yield }, support.operation(&actor, inputs.OBSERVE), support.operation(&actor, inputs.WAIT), support.operation(&actor, inputs.COLLECT), support.operation(&actor, inputs.OBSERVE) });
    try harness.start(&actor);
    try harness.waitStep(&actor, 1);
    const target = if (kind == inputs.COMPLETED) try support.finished(actor.Owner) else if (kind == inputs.EXITED)
        try support.sleeping(actor.Owner)
    else
        try support.faulted(actor.Owner);
    defer support.dispose(target.ID);
    if (kind == inputs.EXITED) try support.terminate(target.ID);
    try support.reclaimed(target.ID);
    try support.identify(&actor, target.ID);
    const expected: types.Record = if (kind == inputs.COMPLETED) .{} else if (kind == inputs.EXITED)
        .{ .Kind = inputs.EXITED, .Result = inputs.RESULT }
    else
        .{ .Kind = inputs.FAULTED, .Vector = access.PAGE_FAULT_VECTOR, .Code = access.EXECUTE_ERROR, .Address = access.DATA_ADDRESS, .Instruction = access.DATA_ADDRESS, .StackPointer = target.Stack };
    var correct = @sizeOf(types.Record) == inputs.RECORD_BYTES;
    for (2..5) |step| {
        try harness.advance(&actor, step - 1);
        try harness.waitStep(&actor, step);
        correct = correct and (try support.response(&actor, step, inputs.SUCCESS, inputs.RECORD_BYTES)) and
            std.meta.eql(expected, try support.record(&actor)) and (try support.guarded(&actor));
    }
    try harness.advance(&actor, 4);
    try harness.waitStep(&actor, 5);
    correct = correct and (try support.response(&actor, 5, inputs.INVALID_TARGET, 0)) and
        std.meta.eql(expected, try support.record(&actor)) and kata.completion.storage.ownerOf(target.ID) == null and
        kata.state.findByID(target.ID) == null;
    verify.require(correct, if (kind == inputs.COMPLETED) labels.COMPLETED else if (kind == inputs.EXITED) labels.EXITED else labels.FAULTED);
}
