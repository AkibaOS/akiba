//! Scheduler Owned Thread Record

const Queue = @import("mirai").sensei.types.queue.links.Queue;
const Thread = @import("mirai").thread.types.thread.Thread;

pub const Record = struct {
    Thread: ?*Thread = null,
    Next: ?*Record = null,
    Previous: ?*Record = null,
    Queue: ?*Queue = null,
};
