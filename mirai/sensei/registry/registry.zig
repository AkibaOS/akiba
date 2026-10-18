//! Scheduler Thread Registration

const state = @import("mirai").sensei.state;
const thread = @import("mirai").thread;
const types = @import("mirai").sensei.types;

const Record = types.record.Record;
const Thread = thread.types.thread.Thread;

pub fn find(target: *const Thread) ?*Record {
    for (&state.getState().Records) |*record| {
        if (record.Thread == target) return record;
    }
    return null;
}

pub fn current() ?*Record {
    return find(thread.state.getCurrent() orelse return null);
}

pub fn reserve(target: *Thread) ?*Record {
    const scheduler = state.getState();
    if (find(target) != null) return null;
    for (&scheduler.Records) |*record| {
        if (record.Thread != null) continue;
        record.* = .{ .Thread = target };
        scheduler.RegisteredCount += 1;
        return record;
    }
    return null;
}

pub fn release(record: *Record) bool {
    const scheduler = state.getState();
    if (record == scheduler.Idle or record.Thread == null or record.Queue != null or record.Next != null or
        scheduler.RegisteredCount == 0) return false;
    record.* = .{};
    scheduler.RegisteredCount -= 1;
    return true;
}
