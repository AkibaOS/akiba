//! Scheduler Thread Registration

const std = @import("std");

const state = @import("mirai").sensei.state;
const thread = @import("mirai").thread;
const types = @import("mirai").sensei.types;

const Record = types.record.Record;
const Thread = thread.types.thread.Thread;

pub fn find(target: *const Thread) ?*Record {
    const slot = thread.state.data(target) orelse return null;
    return if (slot.Scheduler.Thread == target) &slot.Scheduler else null;
}

pub fn current() ?*Record {
    return find(thread.state.getCurrent() orelse return null);
}

pub fn reserve(target: *Thread) ?*Record {
    const scheduler = state.getState();
    const slot = thread.state.data(target) orelse return null;
    const record = &slot.Scheduler;
    if (record.Thread != null or record.Queue != null or record.Next != null or record.Previous != null or
        scheduler.RegisteredCount == std.math.maxInt(usize)) return null;
    record.* = .{ .Thread = target };
    scheduler.RegisteredCount += 1;
    return record;
}

pub fn release(record: *Record) bool {
    const scheduler = state.getState();
    const target = thread.state.fromScheduler(record) orelse return false;
    if (record == scheduler.Idle or record.Thread != target or record.Queue != null or record.Next != null or
        record.Previous != null or record.Deadline != null or record.DeadlinePrevious != null or
        record.DeadlineNext != null or scheduler.RegisteredCount == 0) return false;
    record.* = .{};
    scheduler.RegisteredCount -= 1;
    return true;
}
