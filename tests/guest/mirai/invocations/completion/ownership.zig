//! Open Persona Observation And Adopted Collection Rights

const std = @import("std");

const harness = @import("tests").guest.mirai.postman.harness;
const inputs = @import("tests").constants.completion;
const kata = @import("mirai").kata;
const labels = @import("tests").strings.completion;
const support = @import("tests").guest.mirai.invocations.completion.support;
const types = @import("tests").types.completion;
const verify = @import("tests").guest.support.verify;

pub fn run() !void {
    var owner = try harness.create();
    defer harness.dispose(owner.ID);
    var other = try harness.create();
    defer harness.dispose(other.ID);
    var spoofed = support.operation(&owner, inputs.COLLECT);
    spoofed.LetterType = other.ID;
    try harness.install(&owner, &.{ .{ .Service = .Yield }, spoofed });
    try harness.install(&other, &.{ .{ .Service = .Yield }, support.operation(&other, inputs.OBSERVE), support.operation(&other, inputs.COLLECT), support.operation(&other, inputs.COLLECT) });
    try harness.start(&owner);
    try harness.start(&other);
    try harness.waitStep(&owner, 1);
    try harness.waitStep(&other, 1);
    const target = try support.sleeping(owner.Owner);
    defer support.dispose(target.ID);
    try support.terminate(target.ID);
    try support.identify(&owner, target.ID);
    try support.identify(&other, target.ID);
    const expected: types.Record = .{ .Kind = inputs.EXITED, .Result = inputs.RESULT };
    try harness.advance(&other, 1);
    try harness.waitStep(&other, 2);
    const observed = (try support.response(&other, 2, inputs.SUCCESS, inputs.RECORD_BYTES)) and
        std.meta.eql(expected, try support.record(&other));
    try harness.advance(&other, 2);
    try harness.waitStep(&other, 3);
    verify.require(observed and (try support.response(&other, 3, inputs.NOT_OWNER, 0)) and
        std.meta.eql(expected, try support.record(&other)) and kata.completion.storage.ownerOf(target.ID) == owner.ID, labels.OWNER);
    kata.completion.storage.adopt(owner.ID, other.ID);
    try harness.advance(&owner, 1);
    try harness.waitStep(&owner, 2);
    const revoked = (try support.response(&owner, 2, inputs.NOT_OWNER, 0)) and (try harness.untouched(&owner));
    try harness.advance(&other, 3);
    try harness.waitStep(&other, 4);
    verify.require(revoked and (try support.response(&other, 4, inputs.SUCCESS, inputs.RECORD_BYTES)) and
        std.meta.eql(expected, try support.record(&other)) and (try support.guarded(&other)) and
        kata.completion.storage.ownerOf(target.ID) == null, labels.ADOPTION);
}
