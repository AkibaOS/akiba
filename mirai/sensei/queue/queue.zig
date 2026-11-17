//! Intrusive Scheduling Queues

const std = @import("std");

const messages = @import("mirai").sensei.strings.messages;
const types = @import("mirai").sensei.types;

const Queue = types.queue.Queue;
const Record = types.record.Record;

pub fn append(queue: *Queue, record: *Record) bool {
    if (record.Thread == null or record.Queue != null or record.Next != null or record.Previous != null or
        queue.Count == std.math.maxInt(usize)) return false;
    if (queue.Tail) |tail| {
        if (queue.Head == null or queue.Count == 0 or tail.Queue != queue or tail.Next != null) return false;
        tail.Next = record;
    } else {
        if (queue.Head != null or queue.Count != 0) return false;
        queue.Head = record;
    }
    record.Previous = queue.Tail;
    record.Queue = queue;
    queue.Tail = record;
    queue.Count += 1;
    return true;
}

pub fn take(queue: *Queue) ?*Record {
    const head = queue.Head orelse {
        if (queue.Tail != null or queue.Count != 0) @panic(messages.INVALID_QUEUE);
        return null;
    };
    if (head.Queue != queue or head.Previous != null or queue.Count == 0) @panic(messages.INVALID_QUEUE);
    if (head.Next) |following| {
        if (following.Previous != head or following.Queue != queue) @panic(messages.INVALID_QUEUE);
        following.Previous = null;
    }
    queue.Head = head.Next;
    queue.Count -= 1;
    if (queue.Head == null) {
        if (queue.Count != 0 or queue.Tail != head) @panic(messages.INVALID_QUEUE);
        queue.Tail = null;
    }
    head.Next = null;
    head.Previous = null;
    head.Queue = null;
    return head;
}

pub fn remove(queue: *Queue, record: *Record) bool {
    if (record.Queue != queue or queue.Count == 0) return false;
    if (record.Previous) |previous| {
        if (previous.Queue != queue or previous.Next != record) return false;
    } else if (queue.Head != record) return false;
    if (record.Next) |following| {
        if (following.Queue != queue or following.Previous != record) return false;
    } else if (queue.Tail != record) return false;
    if (record.Previous) |previous| previous.Next = record.Next else queue.Head = record.Next;
    if (record.Next) |following| following.Previous = record.Previous else queue.Tail = record.Previous;
    queue.Count -= 1;
    record.Next = null;
    record.Previous = null;
    record.Queue = null;
    return true;
}
