//! Scheduler Owned Thread Record

const Queue = @import("mirai").sensei.types.queue.Queue;
const Thread = @import("mirai").thread.types.thread.Thread;

pub const Record = struct {
    Thread: ?*Thread = null,
    Next: ?*Record = null,
    Queue: ?*Queue = null,
};
