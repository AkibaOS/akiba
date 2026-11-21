//! Published Completion And Observer Lifetime

const std = @import("std");

const errors = @import("mirai").kata.errors.completion.collection;
const guard = @import("asm").interrupts.guard;
const messages = @import("mirai").kata.strings.messages;
const pending = @import("mirai").kata.completion.pending;
const postman = @import("mirai").postman;
const sensei = @import("mirai").sensei;
const state = @import("mirai").kata.state;
const storage = @import("mirai").kata.completion.storage;
const thread = @import("mirai").thread;
const types = @import("mirai").kata.types;

const Completion = types.completion.result.Completion;
const CompletionError = errors.CompletionError;
const Outcome = types.outcome.Outcome;

pub fn publish(id: u64) bool {
    const flags = guard.acquire();
    defer guard.release(flags);
    const record = storage.find(id) orelse return false;
    if (record.Published or record.Outcome != null or record.Reclaimed) return false;
    record.Published = true;
    return true;
}

pub fn commit(id: u64, outcome: Outcome) bool {
    const flags = guard.acquire();
    defer guard.release(flags);
    const record = storage.find(id) orelse return false;
    if (!record.Published or record.Outcome != null or record.Reclaimed) return false;
    record.Outcome = outcome;
    pending.append(record);
    return true;
}

pub fn release(id: u64) bool {
    const flags = guard.acquire();
    defer guard.release(flags);
    const record = storage.find(id) orelse return false;
    if (record.Reclaimed) return false;
    if (record.Outcome == null) {
        if (record.Published or record.Observers != 0 or record.Waiters.Count != 0) return false;
        return storage.remove(record);
    }
    pending.remove(record);
    record.Reclaimed = true;
    var waiter = record.Waiters.Head;
    while (waiter) |waiting| : (waiter = waiting.Next) sensei.deadline.completed(waiting);
    _ = sensei.wait.wakeAll(&record.Waiters) catch @panic(messages.INVALID_OBSERVER);
    if (state.findByID(record.OwnerID)) |owner| {
        if (postman.inbox.find(owner)) |mailbox| postman.notification.receivers(mailbox);
    }
    return true;
}

pub fn peek(id: u64) ?Outcome {
    const flags = guard.acquire();
    defer guard.release(flags);
    const record = storage.find(id) orelse return null;
    return if (record.Published and record.Reclaimed and !record.Collected) record.Outcome else null;
}

pub fn borrow(id: u64) CompletionError!*Completion {
    const flags = guard.acquire();
    defer guard.release(flags);
    const record = storage.find(id) orelse return CompletionError.InvalidTarget;
    if (!record.Published or record.Collected) return CompletionError.InvalidTarget;
    if (record.Observers == std.math.maxInt(usize)) return CompletionError.ObserverCapacity;
    record.Observers += 1;
    return record;
}

pub fn observed(id: u64) ?Outcome {
    const flags = guard.acquire();
    defer guard.release(flags);
    const record = storage.find(id) orelse return null;
    return if (record.Observers != 0 and record.Reclaimed) record.Outcome else null;
}

pub fn drop(id: u64) void {
    const flags = guard.acquire();
    defer guard.release(flags);
    const record = storage.find(id) orelse @panic(messages.INVALID_OBSERVER);
    if (record.Observers == 0) @panic(messages.INVALID_OBSERVER);
    record.Observers -= 1;
    if (record.Collected and record.Observers == 0) {
        if (record.Waiters.Count != 0 or !storage.remove(record)) @panic(messages.INVALID_OBSERVER);
    }
}

pub fn collect(id: u64) CompletionError!Outcome {
    const flags = guard.acquire();
    defer guard.release(flags);
    const current = thread.state.getCurrent() orelse return CompletionError.InvalidCaller;
    if (!thread.state.owns(current) or current.Status != .Running or !state.owns(current.Owner) or
        current.Owner.State != .Alive) return CompletionError.InvalidCaller;
    const record = storage.find(id) orelse return CompletionError.InvalidTarget;
    if (!record.Published or record.Collected) return CompletionError.InvalidTarget;
    if (record.OwnerID != current.Owner.ID) return CompletionError.NotOwner;
    if (!record.Reclaimed) return CompletionError.NotReady;
    const outcome = record.Outcome orelse @panic(messages.INVALID_OBSERVER);
    record.Collected = true;
    if (record.Observers == 0) {
        if (record.Waiters.Count != 0 or !storage.remove(record)) @panic(messages.INVALID_OBSERVER);
    }
    return outcome;
}
