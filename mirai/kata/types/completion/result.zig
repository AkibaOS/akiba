//! Independently Retained Kata Completion

const Node = @import("common").datatypes.tree.types.node.Node;
const Outcome = @import("mirai").kata.types.outcome.Outcome;
const Queue = @import("mirai").sensei.types.queue.links.Queue;

pub const Completion = struct {
    ID: u64 = 0,
    OwnerID: u64 = 0,
    Outcome: ?Outcome = null,
    Waiters: Queue = .{},
    Observers: usize = 0,
    Published: bool = false,
    Reclaimed: bool = false,
    Collected: bool = false,
    Index: Node = .{},
    OwnerIndex: Node = .{},
    PendingPrevious: ?*Completion = null,
    PendingNext: ?*Completion = null,
    Pending: bool = false,
};
