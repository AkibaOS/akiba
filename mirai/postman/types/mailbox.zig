//! Kata Incoming Mailbox

const Envelope = @import("mirai").postman.types.envelope.Envelope;
const Kata = @import("mirai").kata.types.kata.Kata;
const Queue = @import("mirai").sensei.types.queue.Queue;

pub const Mailbox = struct {
    Owner: ?*Kata = null,
    ID: u64 = 0,
    Closed: bool = false,
    Head: ?*Envelope = null,
    Tail: ?*Envelope = null,
    Queued: usize = 0,
    Held: usize = 0,
    Outgoing: usize = 0,
    Receivers: Queue = .{},
};
