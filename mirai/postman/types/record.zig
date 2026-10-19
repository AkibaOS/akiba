//! Thread Call Ownership

const Envelope = @import("mirai").postman.types.envelope.Envelope;
const Kata = @import("mirai").kata.types.kata.Kata;
const Queue = @import("mirai").sensei.types.queue.Queue;
const Thread = @import("mirai").thread.types.thread.Thread;

pub const Record = struct {
    Thread: ?*Thread = null,
    Owner: ?*Kata = null,
    ID: u64 = 0,
    Pending: ?*Envelope = null,
    Serving: ?*Envelope = null,
    Callers: Queue = .{},
};
