//! Owner Bound Thread Transport Records

const messages = @import("mirai").postman.strings.invariants;
const thread = @import("mirai").thread;

const PostError = @import("mirai").postman.errors.transport.PostError;
const Record = @import("mirai").postman.types.record.Record;
const Thread = thread.types.thread.Thread;

pub fn find(target: *const Thread) ?*Record {
    const slot = thread.state.data(target) orelse return null;
    const entry = &slot.Postman;
    return if (entry.Thread == target and entry.Owner == target.Owner and entry.ID == target.Owner.ID) entry else null;
}

pub fn get(target: *Thread) PostError!*Record {
    if (find(target)) |entry| return entry;
    const slot = thread.state.data(target) orelse return PostError.InvalidThread;
    if (slot.Postman.Thread != null) return PostError.InvalidState;
    slot.Postman = .{ .Thread = target, .Owner = target.Owner, .ID = target.Owner.ID };
    return &slot.Postman;
}

pub fn release(entry: *Record) void {
    if (entry.Pending != null or entry.Serving != null or entry.Callers.Head != null or
        entry.Callers.Tail != null or entry.Callers.Count != 0) @panic(messages.INVALID_RECORD);
    entry.* = .{};
}
