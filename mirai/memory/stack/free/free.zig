//! Kernel Stack Free

const state = @import("../state.zig");
const types = @import("../types/types.zig");

pub fn free(stack: types.KernelStack) void {
    const allocator_state = state.get_state();

    const node: *types.FreeNode = @ptrFromInt(stack.base);
    node.next = allocator_state.free_list;

    allocator_state.free_list = node;
    allocator_state.free_count += 1;
}
