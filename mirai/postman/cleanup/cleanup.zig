//! Thread And Kata Transport Teardown

const guard = @import("asm").interrupts.guard;
const inbox = @import("mirai").postman.inbox;
const kata = @import("mirai").kata;
const lifetime = @import("mirai").postman.lifetime;
const messages = @import("mirai").postman.strings.invariants;
const record = @import("mirai").postman.record;
const sensei = @import("mirai").sensei;
const state = @import("mirai").postman.state;
const storage = @import("mirai").postman.storage;
const thread = @import("mirai").thread;

const Kata = kata.types.kata.Kata;
const Thread = thread.types.thread.Thread;

pub fn threadInactive(target: *Thread) void {
    const previous_flags = guard.acquire();
    defer guard.release(previous_flags);
    if (!state.getState().Initialized or !thread.state.owns(target)) return;
    if (target.Status != .Stopped and (target.Status != .Ready or target.Managed)) return;
    const owner = target.Owner;
    if (!kata.state.owns(owner) or owner.Permanent) return;
    const entry = record.find(target);
    const mailbox = inbox.find(owner);
    if (sensei.registry.find(target)) |scheduled| {
        if (entry) |owned| {
            if (scheduled.Queue == &owned.Callers) @panic(messages.INVALID_WAITERS);
        }
        if (mailbox) |incoming| {
            if (scheduled.Queue == &incoming.Receivers) @panic(messages.INVALID_WAITERS);
        }
    }
    if (entry) |owned| lifetime.clearRecord(owned);
    if (!thread.state.hasLive(owner, target)) {
        const incoming = inbox.get(owner) catch @panic(messages.INVALID_MAILBOX);
        lifetime.close(incoming);
    }
}

pub fn kataRelease(owner: *Kata) void {
    const previous_flags = guard.acquire();
    defer guard.release(previous_flags);
    if (!state.getState().Initialized or !kata.state.owns(owner) or owner.Permanent or owner.ThreadCount != 0) return;
    const mailbox = inbox.find(owner);
    if (mailbox) |incoming| {
        if (incoming.Receivers.Head != null or incoming.Receivers.Tail != null or incoming.Receivers.Count != 0) {
            @panic(messages.INVALID_WAITERS);
        }
        lifetime.close(incoming);
    }
    for (&state.getState().Records) |*entry| {
        if (entry.Owner == owner and entry.ID == owner.ID) lifetime.clearRecord(entry);
    }
    const incoming = mailbox orelse return;
    for (&state.getState().Envelopes) |*envelope| {
        if (envelope.Source != incoming) continue;
        if (envelope.Status == .OneWay) storage.detachSource(envelope) else lifetime.cancelClient(envelope);
    }
    if (incoming.Outgoing != 0 or incoming.Held != 0 or incoming.Queued != 0) @panic(messages.INVALID_MAILBOX);
    incoming.* = .{};
}
