//! Kernel Stack Allocator State

const types = @import("../types/stack/stack.zig");

pub const State = struct {
    next_slot: u64,
    free_list: ?*types.FreeNode,
    free_count: u64,
    total_count: u64,
    high_watermark: u64,
};

var global_state: State = .{
    .next_slot = 0,
    .free_list = null,
    .free_count = 0,
    .total_count = 0,
    .high_watermark = 0,
};

pub fn get_state() *State {
    return &global_state;
}
