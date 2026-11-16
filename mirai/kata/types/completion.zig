//! Independently Retained Kata Completion

const Outcome = @import("mirai").kata.types.outcome.Outcome;
const Queue = @import("mirai").sensei.types.queue.Queue;

pub const Completion = struct {
    ID: u64 = 0,
    OwnerID: u64 = 0,
    Outcome: ?Outcome = null,
    Waiters: Queue = .{},
    Observers: usize = 0,
    Published: bool = false,
    Reclaimed: bool = false,
    Collected: bool = false,
};
