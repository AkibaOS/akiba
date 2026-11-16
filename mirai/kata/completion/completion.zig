//! Owned Retained Outcomes And Observer Lifetime

const constants = @import("mirai").kata.constants.pool;
const errors = @import("mirai").kata.errors.completion;
const guard = @import("asm").interrupts.guard;
const limits = @import("mirai").thread.constants.pool;
const messages = @import("mirai").kata.strings.messages;
const sensei = @import("mirai").sensei;
const state = @import("mirai").kata.state;
const thread = @import("mirai").thread;
const types = @import("mirai").kata.types;

const Completion = types.completion.Completion;
const CompletionError = errors.CompletionError;
const Outcome = types.outcome.Outcome;

var records: [constants.MAX_KATAS]Completion = [_]Completion{.{}} ** constants.MAX_KATAS;

pub fn hasCapacity() bool {
    const previous_flags = guard.acquire();
    defer guard.release(previous_flags);
    for (records) |record| {
        if (record.ID == constants.KERNEL_ID) return true;
    }
    return false;
}

fn find(id: u64) ?*Completion {
    if (id == constants.KERNEL_ID) return null;
    for (&records) |*record| {
        if (record.ID == id) return record;
    }
    return null;
}

pub fn reserve(id: u64, owner_id: u64) bool {
    const previous_flags = guard.acquire();
    defer guard.release(previous_flags);
    if (id == constants.KERNEL_ID or id == owner_id or find(id) != null) return false;
    for (&records) |*record| {
        if (record.ID != constants.KERNEL_ID) continue;
        record.* = .{ .ID = id, .OwnerID = owner_id };
        return true;
    }
    return false;
}

pub fn publish(id: u64) bool {
    const previous_flags = guard.acquire();
    defer guard.release(previous_flags);
    const record = find(id) orelse return false;
    if (record.Published or record.Outcome != null or record.Reclaimed) return false;
    record.Published = true;
    return true;
}

pub fn ownerOf(id: u64) ?u64 {
    const previous_flags = guard.acquire();
    defer guard.release(previous_flags);
    const record = find(id) orelse return null;
    return record.OwnerID;
}

pub fn adopt(previous_owner: u64, new_owner: u64) void {
    const previous_flags = guard.acquire();
    defer guard.release(previous_flags);
    for (&records) |*record| {
        if (record.ID == constants.KERNEL_ID or record.ID == new_owner or record.OwnerID != previous_owner) continue;
        record.OwnerID = new_owner;
    }
}

pub fn commit(id: u64, outcome: Outcome) bool {
    const previous_flags = guard.acquire();
    defer guard.release(previous_flags);
    const record = find(id) orelse return false;
    if (!record.Published or record.Outcome != null or record.Reclaimed) return false;
    record.Outcome = outcome;
    return true;
}

pub fn release(id: u64) bool {
    const previous_flags = guard.acquire();
    defer guard.release(previous_flags);
    const record = find(id) orelse return false;
    if (record.Reclaimed) return false;
    if (record.Outcome == null) {
        if (record.Published or record.Observers != 0 or record.Waiters.Count != 0) return false;
        record.* = .{};
    } else {
        record.Reclaimed = true;
        _ = sensei.wait.wakeAll(&record.Waiters) catch @panic(messages.INVALID_OBSERVER);
    }
    return true;
}

pub fn pending(index: usize) ?u64 {
    const previous_flags = guard.acquire();
    defer guard.release(previous_flags);
    if (index >= records.len) return null;
    const record = &records[index];
    return if (record.Outcome != null and !record.Reclaimed) record.ID else null;
}

pub fn peek(id: u64) ?Outcome {
    const previous_flags = guard.acquire();
    defer guard.release(previous_flags);
    const record = find(id) orelse return null;
    return if (record.Published and record.Reclaimed and !record.Collected) record.Outcome else null;
}

pub fn borrow(id: u64) CompletionError!*Completion {
    const previous_flags = guard.acquire();
    defer guard.release(previous_flags);
    const record = find(id) orelse return CompletionError.InvalidTarget;
    if (!record.Published or record.Collected) return CompletionError.InvalidTarget;
    if (record.Observers >= limits.MAX_THREADS) return CompletionError.ObserverCapacity;
    record.Observers += 1;
    return record;
}

pub fn observed(id: u64) ?Outcome {
    const previous_flags = guard.acquire();
    defer guard.release(previous_flags);
    const record = find(id) orelse return null;
    return if (record.Observers != 0 and record.Reclaimed) record.Outcome else null;
}

pub fn drop(id: u64) void {
    const previous_flags = guard.acquire();
    defer guard.release(previous_flags);
    const record = find(id) orelse @panic(messages.INVALID_OBSERVER);
    if (record.Observers == 0) @panic(messages.INVALID_OBSERVER);
    record.Observers -= 1;
    if (record.Collected and record.Observers == 0) {
        if (record.Waiters.Count != 0) @panic(messages.INVALID_OBSERVER);
        record.* = .{};
    }
}

pub fn collect(id: u64) CompletionError!Outcome {
    const previous_flags = guard.acquire();
    defer guard.release(previous_flags);
    const current = thread.state.getCurrent() orelse return CompletionError.InvalidCaller;
    if (!thread.state.owns(current) or current.Status != .Running or !state.owns(current.Owner) or
        current.Owner.State != .Alive) return CompletionError.InvalidCaller;
    const record = find(id) orelse return CompletionError.InvalidTarget;
    if (!record.Published or record.Collected) return CompletionError.InvalidTarget;
    if (record.OwnerID != current.Owner.ID) return CompletionError.NotOwner;
    if (!record.Reclaimed) return CompletionError.NotReady;
    const outcome = record.Outcome orelse return CompletionError.NotReady;
    record.Collected = true;
    if (record.Observers == 0) {
        if (record.Waiters.Count != 0) @panic(messages.INVALID_OBSERVER);
        record.* = .{};
    }
    return outcome;
}
