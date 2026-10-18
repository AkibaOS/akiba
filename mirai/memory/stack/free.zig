//! Kernel Stack Free

const kagami = @import("mirai").kagami;
const limits = @import("mirai").memory.constants.stack.limits;
const state = @import("mirai").memory.stack.state;
const types = @import("mirai").memory.types;

pub fn free(stack: types.stack.kernel.KernelStack) void {
    const previous_flags = kagami.synchronize.acquire();
    defer kagami.synchronize.release(previous_flags);
    if (!state.isAllocatedBase(stack.Base) or stack.Top != stack.Base + limits.STACK_SIZE or
        state.isPinned(stack.Base)) return;
    const allocator_state = state.getState();
    var current = allocator_state.FreeList;
    var remaining = allocator_state.FreeCount;
    while (current) |cached| {
        if (remaining == 0 or @intFromPtr(cached) == stack.Base) return;
        current = cached.Next;
        remaining -= 1;
    }
    const node: *types.stack.node.FreeNode = @ptrFromInt(stack.Base);
    node.Next = allocator_state.FreeList;
    allocator_state.FreeList = node;
    allocator_state.FreeCount += 1;
}
