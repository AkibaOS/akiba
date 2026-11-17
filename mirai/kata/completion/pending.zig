//! Unreclaimed Terminal Kata Tracking

const guard = @import("asm").interrupts.guard;
const messages = @import("mirai").kata.strings.messages;
const types = @import("mirai").kata.types;

const Completion = types.completion.Completion;

var head: ?*Completion = null;
var tail: ?*Completion = null;

pub fn append(record: *Completion) void {
    const flags = guard.acquire();
    defer guard.release(flags);
    if (record.Pending or record.PendingPrevious != null or record.PendingNext != null) @panic(messages.INVALID_CLEANUP);
    record.PendingPrevious = tail;
    if (tail) |previous| {
        previous.PendingNext = record;
    } else {
        head = record;
    }
    tail = record;
    record.Pending = true;
}

pub fn remove(record: *Completion) void {
    const flags = guard.acquire();
    defer guard.release(flags);
    if (!record.Pending) @panic(messages.INVALID_CLEANUP);
    if (record.PendingPrevious) |previous| {
        previous.PendingNext = record.PendingNext;
    } else {
        if (head != record) @panic(messages.INVALID_CLEANUP);
        head = record.PendingNext;
    }
    if (record.PendingNext) |following| {
        following.PendingPrevious = record.PendingPrevious;
    } else {
        if (tail != record) @panic(messages.INVALID_CLEANUP);
        tail = record.PendingPrevious;
    }
    record.PendingPrevious = null;
    record.PendingNext = null;
    record.Pending = false;
}

pub fn first() ?*Completion {
    const flags = guard.acquire();
    defer guard.release(flags);
    return head;
}

pub fn next(record: *const Completion) ?*Completion {
    const flags = guard.acquire();
    defer guard.release(flags);
    return if (record.Pending) record.PendingNext else null;
}
