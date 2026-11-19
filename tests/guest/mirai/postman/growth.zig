//! Global Envelope Growth Across Real Live Mailbox Owners

const std = @import("std");

const budget = @import("tests").guest.support.allocation;
const guard = @import("asm").interrupts.guard;
const inputs = @import("tests").guest.constants.postman;
const kata = @import("mirai").kata;
const labels = @import("tests").guest.strings.postman;
const memory = @import("mirai").memory;
const pmm = @import("mirai").pmm;
const postman = @import("mirai").postman;
const sensei = @import("mirai").sensei;
const support = @import("tests").guest.mirai.sensei.support;
const thread = @import("mirai").thread;
const verify = @import("tests").guest.support.verify;

const Envelope = postman.types.envelope.Envelope;
const Mailbox = postman.types.mailbox.Mailbox;
const Queue = sensei.types.queue.Queue;
const Thread = thread.types.thread.Thread;
const LIMIT = postman.constants.limits.MAX_QUEUED_LETTERS;

var identifiers = [_]u64{0} ** (2 * inputs.GROWTH_PAIRS);
var targets = [_]?*Thread{null} ** identifiers.len;
var retained: [inputs.GROWTH_PAIRS][LIMIT]?*Envelope = [_][LIMIT]?*Envelope{[_]?*Envelope{null} ** LIMIT} ** inputs.GROWTH_PAIRS;
var waiters: Queue = .{};
var entered: usize = 0;

fn warmStacks() !void {
    var stacks = [_]?memory.types.stack.kernel.KernelStack{null} ** (memory.constants.stack.limits.CACHE_TARGET + 1);
    defer for (stacks) |stack| {
        if (stack) |live| memory.stack.free.free(live);
    };
    for (&stacks) |*stack| stack.* = try memory.stack.allocate.allocate();
    for (&stacks) |*stack| {
        memory.stack.free.free(stack.*.?);
        stack.* = null;
    }
    _ = memory.stack.collect.collect();
}

fn mailbox(index: usize) *Mailbox {
    return postman.inbox.find(kata.state.findByID(identifiers[index]).?).?;
}

fn reservations() !void {
    const source = mailbox(0);
    const destination = mailbox(1);
    const before = pmm.state.getStatistics();
    const search = pmm.state.getState().SearchStart;
    const count = postman.storage.count();
    var failures: usize = 0;
    var accepted: ?*Envelope = null;
    while (true) : (failures += 1) {
        budget.arm(failures);
        if (postman.storage.reserve(source, destination, .OneWay, inputs.LETTER_TYPE, &inputs.REQUEST)) |envelope| {
            accepted = envelope;
            budget.clear();
            break;
        } else |failure| {
            budget.clear();
            verify.require(failure == error.NoResources and source.Outgoing == 0 and destination.Held == 0 and
                destination.Queued == 0 and destination.Head == null and destination.Tail == null and
                source.OutgoingHead == null and destination.HeldHead == null and postman.storage.count() == count and
                search == pmm.state.getState().SearchStart and std.meta.eql(before, pmm.state.getStatistics()), labels.RESERVATION_FAILURE);
        }
    }
    budget.arm(0);
    postman.storage.release(accepted.?);
    budget.clear();
    verify.require(failures != 0 and postman.storage.count() == count and std.meta.eql(before, pmm.state.getStatistics()), labels.RESERVATION_RECOVERY);
}

fn policies() !void {
    const first = mailbox(0);
    const second = mailbox(2);
    const destination = mailbox(1);
    const other = mailbox(3);
    const held_limit = postman.constants.limits.MAX_HELD_LETTERS;
    const outgoing_limit = postman.constants.limits.MAX_OUTGOING_LETTERS;
    var held = [_]?*Envelope{null} ** held_limit;
    for (&held, 0..) |*envelope, index|
        envelope.* = try postman.storage.reserve(if (index < held_limit / 2) first else second, destination, .Queued, index, &inputs.REQUEST);
    var refused = false;
    if (postman.storage.reserve(first, destination, .Queued, 0, &inputs.REQUEST)) |unexpected| {
        postman.storage.release(unexpected);
    } else |failure| refused = failure == error.Full;
    verify.require(refused and destination.Held == held_limit and destination.Queued == 0 and first.Outgoing < outgoing_limit, labels.HELD_CAPACITY);
    budget.arm(0);
    for (held) |envelope| postman.storage.release(envelope.?);
    budget.clear();
    var outgoing = [_]?*Envelope{null} ** outgoing_limit;
    for (&outgoing, 0..) |*envelope, index|
        envelope.* = try postman.storage.reserve(first, if (index < outgoing_limit / 2) destination else other, .Queued, index, &inputs.REQUEST);
    refused = false;
    if (postman.storage.reserve(first, destination, .Queued, 0, &inputs.REQUEST)) |unexpected| {
        postman.storage.release(unexpected);
    } else |failure| refused = failure == error.Full;
    verify.require(refused and first.Outgoing == outgoing_limit and destination.Held < held_limit and destination.Queued == 0, labels.OUTGOING_CAPACITY);
    budget.arm(0);
    for (outgoing) |envelope| postman.storage.release(envelope.?);
    budget.clear();
    const self = try postman.storage.reserve(first, first, .OneWay, inputs.LETTER_TYPE, &inputs.REQUEST);
    postman.fifo.append(first, self);
    const independent = first.Outgoing == 1 and first.Held == 1 and first.Queued == 1 and
        first.OutgoingHead == self and first.HeldHead == self and first.Head == self;
    budget.arm(0);
    postman.lifetime.discardLetter(self);
    budget.clear();
    verify.require(independent and first.Outgoing == 0 and first.Held == 0 and first.Queued == 0 and
        first.OutgoingHead == null and first.HeldHead == null and first.Head == null and first.Tail == null, labels.SELF_DELIVERY);
}

fn waiting(_: ?*anyopaque) bool {
    return false;
}

fn entry(_: ?*anyopaque) callconv(.{ .x86_64_sysv = .{} }) noreturn {
    const current = thread.state.getCurrent().?;
    _ = postman.inbox.get(current.Owner) catch |failure| verify.failure(failure);
    const flags = guard.acquire();
    entered += 1;
    guard.release(flags);
    sensei.wait.blockUntil(&waiters, waiting, null) catch |failure| verify.failure(failure);
    thread.finish.complete();
}

pub fn run() !void {
    defer {
        budget.clear();
        for (&identifiers) |*identifier| {
            if (identifier.* != 0) support.dispose(identifier.*) catch |failure| verify.failure(failure);
            identifier.* = 0;
        }
        _ = memory.stack.collect.collect();
    }
    try warmStacks();
    const before = pmm.state.getStatistics();
    waiters = .{};
    entered = 0;
    {
        const flags = guard.acquire();
        defer guard.release(flags);
        for (&identifiers, &targets) |*identifier, *target| {
            const owner = try kata.create.create();
            identifier.* = owner.ID;
            target.* = try thread.create.create(owner, entry, null);
            try sensei.control.start(target.*.?);
        }
    }
    try support.drain(identifiers[0]);
    const flags = guard.acquire();
    defer guard.release(flags);
    verify.require(entered == identifiers.len and waiters.Count == identifiers.len, labels.GROWTH);
    try reservations();
    try policies();
    const live_peers = pmm.state.getStatistics();
    const envelopes = postman.storage.count();
    for (&retained, 0..) |*letters, index| {
        const source = postman.inbox.find(kata.state.findByID(identifiers[2 * index]).?).?;
        const destination = postman.inbox.find(kata.state.findByID(identifiers[2 * index + 1]).?).?;
        for (letters, 0..) |*letter, ordinal| {
            letter.* = try postman.storage.reserve(source, destination, .OneWay, ordinal, &inputs.REQUEST);
            postman.fifo.append(destination, letter.*.?);
        }
    }
    var stable = true;
    for (retained, 0..) |letters, index| {
        const source = postman.inbox.find(kata.state.findByID(identifiers[2 * index]).?).?;
        const destination = postman.inbox.find(kata.state.findByID(identifiers[2 * index + 1]).?).?;
        stable = stable and source.Outgoing == LIMIT and destination.Held == LIMIT and destination.Queued == LIMIT;
        var current = destination.Head;
        for (letters, 0..) |letter, ordinal| {
            stable = stable and current == letter and letter.?.Header.Type == ordinal and
                letter.?.Header.Sender == source.ID and std.mem.eql(u8, letter.?.Payload[0..inputs.REQUEST.len], &inputs.REQUEST);
            current = letter.?.Next;
        }
        stable = stable and current == null;
    }
    verify.require(stable, labels.GROWTH_STABLE);
    budget.arm(0);
    for (0..inputs.GROWTH_PAIRS) |index| {
        const destination = postman.inbox.find(kata.state.findByID(identifiers[2 * index + 1]).?).?;
        postman.lifetime.close(destination);
    }
    verify.require(postman.storage.count() == envelopes, labels.GROWTH_EMPTY);
    verify.require(std.meta.eql(live_peers, pmm.state.getStatistics()), labels.GROWTH_BACKING);
    for (&identifiers) |*identifier| {
        try support.dispose(identifier.*);
        identifier.* = 0;
    }
    budget.clear();
    _ = memory.stack.collect.collect();
    verify.require(waiters.Count == 0, labels.GROWTH_PEERS);
    verify.require(std.meta.eql(before, pmm.state.getStatistics()), labels.GROWTH_RELEASE);
}
