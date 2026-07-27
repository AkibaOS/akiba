//! Kernel Stack Allocator State

const types = @import("../types/types.zig");

pub const State = struct {
    NextSlot: u64,
    FreeList: ?*types.stack.node.FreeNode,
    FreeCount: u64,
    TotalCount: u64,
    HighWatermark: u64,
};

var global_state: State = .{
    .NextSlot = 0,
    .FreeList = null,
    .FreeCount = 0,
    .TotalCount = 0,
    .HighWatermark = 0,
};

pub fn getState() *State {
    return &global_state;
}
