//! Image Validation Before Resource Reservation

const std = @import("std");

const bootstrap = @import("mirai").bootstrap;
const fixture = @import("tests").fixtures.bytes.elf;
const guard = @import("asm").interrupts.guard;
const inputs = @import("tests").fixtures.constants.elf;
const kata = @import("mirai").kata;
const labels = @import("tests").guest.strings.elf;
const pmm = @import("mirai").pmm;
const thread = @import("mirai").thread;
const verify = @import("tests").guest.support.verify;

const VALID = fixture.create();
const MALFORMED = blk: {
    var bytes = fixture.create();
    bytes[0] = 0;
    break :blk bytes;
};

pub fn run() !void {
    const flags = guard.acquire();
    defer guard.release(flags);
    const marker = try kata.create.create();
    const identifier = marker.ID;
    try kata.destroy.destroy(marker);
    const before = pmm.state.getStatistics();
    const options: bootstrap.types.image.preparation.Options = .{ .StackBase = inputs.STACK_ADDRESS, .StackPages = 2 };
    var correct = rejects(&MALFORMED, options, error.InvalidHeader);
    var bad = options;
    bad.StackPages = 0;
    correct = rejects(&VALID, bad, error.InvalidStack) and correct;
    bad = options;
    bad.StackBase += 1;
    correct = rejects(&VALID, bad, error.InvalidStack) and correct;
    bad = options;
    bad.StackPages = std.math.maxInt(u64);
    correct = rejects(&VALID, bad, error.InvalidStack) and correct;
    bad = options;
    bad.StackBase = inputs.USER_END + 1 - inputs.PAGE_BYTES;
    bad.StackPages = 1;
    correct = rejects(&VALID, bad, error.InvalidStack) and correct;
    bad = options;
    bad.StackBase = inputs.CODE_ADDRESS + inputs.PAGE_BYTES;
    correct = rejects(&VALID, bad, error.StackOverlap) and correct;
    bad.StackBase = inputs.CODE_ADDRESS + 4 * inputs.PAGE_BYTES;
    correct = rejects(&VALID, bad, error.StackOverlap) and correct;
    bad.StackBase = inputs.CODE_ADDRESS - 2 * inputs.PAGE_BYTES;
    correct = rejects(&VALID, bad, error.StackOverlap) and correct;
    bad = options;
    bad.Startup = .{ .Identity = &.{}, .Parameters = &.{} };
    correct = rejects(&VALID, bad, error.InvalidStartup) and correct;
    bad.Startup = .{ .Identity = labels.STARTUP_IDENTITY, .Parameters = &.{} };
    bad.Argument = inputs.ARGUMENT;
    correct = rejects(&VALID, bad, error.InvalidStartup) and correct;
    const next = try kata.create.create();
    const unchanged_ids = next.ID == identifier + 1;
    try kata.destroy.destroy(next);
    verify.require(correct and unchanged_ids and std.meta.eql(before, pmm.state.getStatistics()), labels.REJECT);
}

fn rejects(bytes: []const u8, options: bootstrap.types.image.preparation.Options, expected: anyerror) bool {
    const image = bootstrap.image.prepare.prepare(thread.state.getCurrent().?.Owner, bytes, options) catch |failure| return failure == expected;
    bootstrap.image.abort.abort(image) catch |failure| verify.failure(failure);
    return false;
}
