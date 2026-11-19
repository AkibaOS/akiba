//! Owned ELF Image Preparation And Abort Checks

const std = @import("std");

const bootstrap = @import("mirai").bootstrap;
const fixture = @import("tests").fixtures.bytes.elf;
const guard = @import("asm").interrupts.guard;
const inputs = @import("tests").fixtures.constants.elf;
const kagami = @import("mirai").kagami;
const kata = @import("mirai").kata;
const labels = @import("tests").guest.strings.elf;
const sensei = @import("mirai").sensei;
const support = @import("tests").guest.mirai.sensei.support;
const thread = @import("mirai").thread;
const user = @import("mirai").user;
const verify = @import("tests").guest.support.verify;

const IMAGE_BYTES = fixture.create();
const SHARED_BYTES = blk: {
    var bytes = fixture.create();
    fixture.share(&bytes, false);
    break :blk bytes;
};

pub fn run() !void {
    const image = try prepare(&IMAGE_BYTES);
    var aborted = false;
    defer if (!aborted) bootstrap.image.abort.abort(image) catch |failure| verify.failure(failure);
    verify.require(image.Owner.State == .Born and image.Owner.ThreadCount == 1 and image.Owner.LiveThreadCount == 0 and
        image.Thread.Mode == .Persona and !image.Thread.Managed and !image.Thread.Admitted and
        image.Thread.User.RIP == inputs.CODE_ADDRESS + 1 and image.Thread.User.Argument == inputs.ARGUMENT and
        image.Owner.AddressSpace.?.ResidentPages == 6 and kata.completion.lifetime.peek(image.ID) == null, labels.BORN);
    try contents(image.Owner);
    rights(image.Owner);
    kagami.destroy.reference(image.Owner.AddressSpace.?);
    var refused = false;
    bootstrap.image.abort.abort(image) catch |failure| {
        refused = failure == error.InUse;
    };
    _ = image.Owner.AddressSpace.?.decrementReference();
    verify.require(refused and thread.state.owns(image.Thread) and image.Owner.ThreadCount == 1 and
        image.Owner.State == .Born, labels.IN_USE);
    try bootstrap.image.abort.abort(image);
    aborted = true;
    var stale = false;
    bootstrap.image.abort.abort(image) catch |failure| {
        stale = failure == error.InvalidImage;
    };
    verify.require(stale and kata.state.findByID(image.ID) == null and kata.completion.storage.ownerOf(image.ID) == null and
        !thread.state.owns(image.Thread), labels.ABORT);
    const shared = try prepare(&SHARED_BYTES);
    defer bootstrap.image.abort.abort(shared) catch |failure| verify.failure(failure);
    var reused = false;
    bootstrap.image.abort.abort(image) catch |failure| {
        reused = failure == error.InvalidImage;
    };
    verify.require(reused and kata.state.owns(shared.Owner) and shared.Owner.ThreadCount == 1, labels.ABORT);
    var code: [0x120]u8 = undefined;
    try user.copy.transfer.read(shared.Owner, &code, inputs.CODE_ADDRESS);
    verify.require(shared.Owner.AddressSpace.?.ResidentPages == 5 and
        std.mem.allEqual(u8, code[0..32], 0x90) and std.mem.allEqual(u8, code[0x100..], 0x5a) and
        !kagami.extract.isMapped(shared.Owner.AddressSpace.?, inputs.CODE_ADDRESS + inputs.PAGE_BYTES) and
        kagami.extract.isExecutable(shared.Owner.AddressSpace.?, inputs.CODE_ADDRESS) and
        !kagami.extract.isWritable(shared.Owner.AddressSpace.?, inputs.CODE_ADDRESS), labels.RIGHTS);
    try recycled();
    try published();
}

fn recycled() !void {
    const flags = guard.acquire();
    defer guard.release(flags);
    const image = try prepare(&IMAGE_BYTES);
    defer support.dispose(image.ID) catch |failure| verify.failure(failure);
    try thread.destroy.destroy(image.Thread);
    const replacement = try thread.user.create(image.Owner, inputs.CODE_ADDRESS + 1, inputs.STACK_ADDRESS, 2 * inputs.PAGE_BYTES, inputs.ARGUMENT);
    var refused = false;
    bootstrap.image.abort.abort(image) catch |failure| {
        refused = failure == error.InvalidImage;
    };
    verify.require(replacement == image.Thread and thread.state.generation(replacement).? > image.ThreadGeneration and
        refused and thread.state.owns(replacement) and
        kata.state.owns(image.Owner) and image.Owner.State == .Born and image.Owner.ThreadCount == 1, labels.RECYCLED_THREAD);
    const rejected = if (bootstrap.image.start.start(image)) |_| false else |failure| failure == error.InvalidImage;
    const untouched = image.Owner.State == .Born and image.Owner.LiveThreadCount == 0 and
        !replacement.Managed and !replacement.Admitted and !observable(image.ID);
    try support.dispose(image.ID);
    verify.require(rejected and untouched, labels.RECYCLED_START);
}

fn published() !void {
    const flags = guard.acquire();
    defer guard.release(flags);
    const image = try prepare(&IMAGE_BYTES);
    defer support.dispose(image.ID) catch |failure| verify.failure(failure);
    const rejected = denied: {
        sensei.preemption.disable();
        defer sensei.preemption.enable();
        break :denied if (bootstrap.image.start.start(image)) |_| false else |failure| failure == error.UnsafeContext;
    };
    verify.require(rejected and image.Owner.State == .Born and image.Owner.LiveThreadCount == 0 and
        !image.Thread.Managed and !image.Thread.Admitted and !observable(image.ID), labels.START_REFUSED);
    const identifier = try bootstrap.image.start.start(image);
    const duplicate = if (bootstrap.image.start.start(image)) |_| false else |failure| failure == error.InUse;
    verify.require(identifier == image.ID and duplicate and image.Owner.State == .Alive and image.Owner.LiveThreadCount == 1 and
        image.Owner.RunnableThreadCount == 1 and image.Thread.Mode == .Persona and observable(identifier), labels.START_ONCE);
    var refused = false;
    bootstrap.image.abort.abort(image) catch |failure| {
        refused = failure == error.InUse;
    };
    const intact = refused and image.Owner.State == .Alive and image.Thread.Managed and image.Thread.Admitted;
    try support.dispose(image.ID);
    verify.require(intact and kata.state.findByID(image.ID) == null and kata.completion.storage.ownerOf(image.ID) == null, labels.IN_USE);
}

fn observable(identifier: u64) bool {
    _ = kata.completion.lifetime.borrow(identifier) catch return false;
    kata.completion.lifetime.drop(identifier);
    return true;
}

fn prepare(bytes: []const u8) !bootstrap.types.image.Prepared {
    return bootstrap.image.prepare.prepare(thread.state.getCurrent().?.Owner, bytes, .{
        .StackBase = inputs.STACK_ADDRESS,
        .StackPages = 2,
        .Argument = inputs.ARGUMENT,
    });
}

fn contents(owner: *kata.types.kata.Kata) !void {
    var bytes: [inputs.PAGE_BYTES]u8 = undefined;
    var correct = true;
    for (0..4) |index| {
        try user.copy.transfer.read(owner, &bytes, inputs.CODE_ADDRESS + index * inputs.PAGE_BYTES);
        const count: usize = if (index < 2) 32 else if (index == 2) inputs.PAGE_BYTES else 1;
        const value: u8 = if (index == 0) 0x90 else if (index == 1) 0x5a else 0x3c;
        correct = correct and std.mem.allEqual(u8, bytes[0..count], value) and std.mem.allEqual(u8, bytes[count..], 0);
    }
    verify.require(correct, labels.CONTENTS);
}

fn rights(owner: *kata.types.kata.Kata) void {
    var correct = true;
    for (0..4) |index| {
        const address = inputs.CODE_ADDRESS + index * inputs.PAGE_BYTES;
        const mapping = kagami.extract.lookup(owner.AddressSpace.?, address).?;
        const record = user.state.ledger.find(owner, address).?;
        const alias = user.state.checks.lookupAlias(record).?;
        correct = correct and mapping.UserAccessible and mapping.Writable == (index >= 2) and
            mapping.Executable == (index == 0) and !alias.UserAccessible and !alias.Executable and alias.Writable == (index >= 2);
    }
    verify.require(correct, labels.RIGHTS);
    verify.require(!kagami.extract.isMapped(owner.AddressSpace.?, inputs.STACK_ADDRESS - inputs.PAGE_BYTES) and
        !kagami.extract.isMapped(owner.AddressSpace.?, inputs.STACK_ADDRESS + 2 * inputs.PAGE_BYTES) and
        kagami.extract.isWritable(owner.AddressSpace.?, inputs.STACK_ADDRESS) and
        !kagami.extract.isExecutable(owner.AddressSpace.?, inputs.STACK_ADDRESS), labels.STACK);
}
