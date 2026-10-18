//! Intrusive Scheduling Queues

const messages = @import("mirai").sensei.strings.messages;
const policy = @import("mirai").sensei.constants.policy;
const types = @import("mirai").sensei.types;

const Queue = types.queue.Queue;
const Record = types.record.Record;

pub fn append(queue: *Queue, record: *Record) bool {
    if (record.Thread == null or record.Queue != null or record.Next != null or queue.Count >= policy.MAX_RECORDS) return false;
    if (queue.Tail) |tail| {
        if (queue.Head == null or queue.Count == 0 or tail.Queue != queue or tail.Next != null) return false;
        tail.Next = record;
    } else {
        if (queue.Head != null or queue.Count != 0) return false;
        queue.Head = record;
    }
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
    if (head.Queue != queue or queue.Count == 0) @panic(messages.INVALID_QUEUE);
    queue.Head = head.Next;
    queue.Count -= 1;
    if (queue.Head == null) {
        if (queue.Count != 0 or queue.Tail != head) @panic(messages.INVALID_QUEUE);
        queue.Tail = null;
    }
    head.Next = null;
    head.Queue = null;
    return head;
}

pub fn remove(queue: *Queue, record: *Record) bool {
    if (record.Queue != queue or queue.Count == 0) return false;
    var previous: ?*Record = null;
    var current = queue.Head;
    var remaining = queue.Count;
    while (current) |candidate| {
        if (remaining == 0) @panic(messages.INVALID_QUEUE);
        if (candidate == record) {
            if (previous) |before| before.Next = candidate.Next else queue.Head = candidate.Next;
            if (queue.Tail == candidate) queue.Tail = previous;
            queue.Count -= 1;
            candidate.Next = null;
            candidate.Queue = null;
            return true;
        }
        previous = candidate;
        current = candidate.Next;
        remaining -= 1;
    }
    return false;
}
