//! Kernel Stack Free

const state = @import("state.zig");
const types = @import("../types/types.zig");

pub fn free(stack: types.stack.kernel.KernelStack) void {
    const allocator_state = state.getState();

    const node: *types.stack.node.FreeNode = @ptrFromInt(stack.Base);
    node.Next = allocator_state.FreeList;

    allocator_state.FreeList = node;
    allocator_state.FreeCount += 1;
}
