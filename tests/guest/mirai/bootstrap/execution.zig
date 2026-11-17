//! Compiler Produced ELF Persona Execution And Owned Outcome

const std = @import("std");

const bootstrap = @import("mirai").bootstrap;
const completion = @import("tests").guest.mirai.invocations.completion.support;
const driver = @import("tests").guest.mirai.sensei.support;
const guard = @import("asm").interrupts.guard;
const harness = @import("tests").guest.mirai.postman.harness;
const inputs = @import("tests").constants.elf;
const invocations = @import("tests").constants.completion;
const kata = @import("mirai").kata;
const labels = @import("tests").strings.elf;
const sensei = @import("mirai").sensei;
const shared = @import("shared").elf;
const thread = @import("mirai").thread;
const types = @import("tests").types.completion;
const user = @import("mirai").user;
const verify = @import("tests").verify;

const IMAGE_BYTES = @embedFile("elfimage");
var finished: bool = false;

pub fn run() !void {
    finished = false;
    const owner = try kata.create.create();
    const identifier = owner.ID;
    defer harness.dispose(identifier);
    try sensei.control.start(try thread.create.create(owner, entry, null));
    try driver.drain(identifier);
    const outcome = try kata.completion.collect(identifier);
    verify.require(finished and outcome == .Completed and kata.state.findByID(identifier) == null, labels.OUTCOME);
}

fn entry(_: ?*anyopaque) callconv(.{ .x86_64_sysv = .{} }) noreturn {
    execute(0) catch |failure| verify.failure(failure);
    execute(inputs.BAD_ARGUMENT_RESULT) catch |failure| verify.failure(failure);
    execute(inputs.BAD_DATA_RESULT) catch |failure| verify.failure(failure);
    finished = true;
    thread.finish.complete();
}

fn execute(comptime failure: u64) !void {
    var actor = try harness.create();
    defer harness.dispose(actor.ID);
    try harness.install(&actor, &.{ .{ .Service = .Yield }, completion.operation(&actor, invocations.WAIT), completion.operation(&actor, invocations.OBSERVE), completion.operation(&actor, invocations.COLLECT) });
    try harness.start(&actor);
    try harness.waitStep(&actor, 1);
    const image = try bootstrap.image.prepare.prepare(actor.Owner, IMAGE_BYTES, .{
        .StackBase = inputs.STACK_ADDRESS,
        .StackPages = 2,
        .Argument = if (failure == inputs.BAD_ARGUMENT_RESULT) inputs.ARGUMENT ^ 1 else inputs.ARGUMENT,
    });
    defer completion.dispose(image.ID);
    try inspect(image.Owner);
    if (failure == inputs.BAD_DATA_RESULT) {
        const plan = try shared.validate.image.parse(IMAGE_BYTES, .{
            .MinimumAddress = inputs.PAGE_BYTES,
            .MaximumAddress = inputs.USER_END,
            .MaximumPages = inputs.MAXIMUM_PAGES,
        });
        try user.copy.transfer.write(image.Owner, plan.Segments[2].VirtualAddress, &.{0});
    }
    const persona = image.Thread.Mode == .Persona and image.Owner.State == .Born and
        kata.completion.ownerOf(image.ID) == actor.ID;
    try completion.identify(&actor, image.ID);
    try harness.advance(&actor, 1);
    {
        const flags = guard.acquire();
        defer guard.release(flags);
        try sensei.control.start(image.Thread);
        sensei.run.rescheduleTo(false, actor.Target.?);
    }
    try harness.waitStep(&actor, 2);
    const expected: types.Record = .{ .Kind = invocations.EXITED, .Result = if (failure == 0) inputs.EXIT_RESULT else failure };
    verify.require(persona and (try completion.response(&actor, 2, invocations.SUCCESS, invocations.RECORD_BYTES)) and
        std.meta.eql(expected, try completion.record(&actor)) and kata.state.findByID(image.ID) == null, if (failure == 0) labels.EXECUTION else labels.NEGATIVE);
    for (3..5) |step| {
        try harness.advance(&actor, step - 1);
        try harness.waitStep(&actor, step);
        verify.require((try completion.response(&actor, step, invocations.SUCCESS, invocations.RECORD_BYTES)) and
            std.meta.eql(expected, try completion.record(&actor)) and (try completion.guarded(&actor)), labels.OUTCOME);
    }
    verify.require(kata.completion.ownerOf(image.ID) == null and !thread.state.owns(image.Thread), labels.ABORT);
}

fn inspect(owner: *kata.types.kata.Kata) !void {
    const plan = try shared.validate.image.parse(IMAGE_BYTES, .{
        .MinimumAddress = inputs.PAGE_BYTES,
        .MaximumAddress = inputs.USER_END,
        .MaximumPages = inputs.MAXIMUM_PAGES,
    });
    var actual: [inputs.PAGE_BYTES]u8 = undefined;
    var correct = plan.Count == 3 and plan.Entry == inputs.COMPILER_ENTRY;
    for (plan.Segments[0..plan.Count]) |segment| {
        var offset: u64 = 0;
        while (offset < segment.MemorySize) {
            const count: usize = @intCast(@min(inputs.PAGE_BYTES, segment.MemorySize - offset));
            try user.copy.transfer.read(owner, actual[0..count], segment.VirtualAddress + offset);
            const initialized: usize = if (offset < segment.UnitSize) @intCast(@min(count, segment.UnitSize - offset)) else 0;
            if (initialized != 0) {
                const source: usize = @intCast(segment.Offset + offset);
                correct = correct and std.mem.eql(u8, actual[0..initialized], IMAGE_BYTES[source..][0..initialized]);
            }
            correct = correct and std.mem.allEqual(u8, actual[initialized..count], 0);
            offset += count;
        }
    }
    verify.require(correct, labels.CONTENTS);
}
