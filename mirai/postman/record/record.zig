//! Postman Thread Record Allocation

const messages = @import("mirai").postman.strings.invariants;
const state = @import("mirai").postman.state;

const PostError = @import("mirai").postman.errors.transport.PostError;
const Record = @import("mirai").postman.types.record.Record;
const Thread = @import("mirai").thread.types.thread.Thread;

pub fn find(target: *const Thread) ?*Record {
    for (&state.getState().Records) |*entry| {
        if (entry.Thread == target and entry.Owner == target.Owner and entry.ID == target.Owner.ID) return entry;
    }
    return null;
}

pub fn get(target: *Thread) PostError!*Record {
    if (find(target)) |entry| return entry;
    for (&state.getState().Records) |*entry| {
        if (entry.Thread != null) continue;
        entry.* = .{ .Thread = target, .Owner = target.Owner, .ID = target.Owner.ID };
        return entry;
    }
    return PostError.NoResources;
}

pub fn release(entry: *Record) void {
    if (entry.Pending != null or entry.Serving != null or entry.Callers.Head != null or
        entry.Callers.Tail != null or entry.Callers.Count != 0) @panic(messages.INVALID_RECORD);
    entry.* = .{};
}
