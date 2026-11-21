//! Wake Managed Waiters At Their Monotonic Tick Deadline

const std = @import("std");

const guard = @import("asm").interrupts.guard;
const messages = @import("mirai").sensei.strings.messages;
const state = @import("mirai").sensei.state;
const wait = @import("mirai").sensei.wait;

const Record = @import("mirai").sensei.types.record.Record;

var pending: ?*Record = null;

pub fn arm(record: *Record, ticks: u64) !void {
    if (ticks == 0 or record.Deadline != null) return error.InvalidArgument;
    const until = std.math.add(u64, state.getState().Ticks, ticks) catch return error.InvalidArgument;
    record.Deadline = until;
    record.TimedOut = false;
    record.DeadlinePrevious = null;
    record.DeadlineNext = pending;
    if (pending) |next| next.DeadlinePrevious = record;
    pending = record;
}

pub fn cancel(record: *Record) void {
    if (record.Deadline != null) unlink(record);
    record.TimedOut = false;
}

pub fn completed(record: *Record) void {
    if (record.Deadline == null) return;
    unlink(record);
    record.TimedOut = false;
}

pub fn tick() void {
    expire(state.getState().Ticks);
}

pub fn expire(now: u64) void {
    const flags = guard.acquire();
    defer guard.release(flags);
    var current = pending;
    while (current) |record| {
        current = record.DeadlineNext;
        if (record.Deadline.? > now) continue;
        unlink(record);
        record.TimedOut = true;
        if (record.Thread) |target| _ = wait.wake(target) catch @panic(messages.INVALID_STATE);
    }
}

fn unlink(record: *Record) void {
    if (record.DeadlinePrevious) |previous| previous.DeadlineNext = record.DeadlineNext else pending = record.DeadlineNext;
    if (record.DeadlineNext) |next| next.DeadlinePrevious = record.DeadlinePrevious;
    record.Deadline = null;
    record.DeadlinePrevious = null;
    record.DeadlineNext = null;
}
