//! Kernel Stack Cache Release

const guard = @import("asm").interrupts.guard;
const state = @import("mirai").memory.stack.state;
const types = @import("mirai").memory.types.stack;

pub fn free(stack: types.kernel.KernelStack) void {
    const flags = guard.acquire();
    defer guard.release(flags);
    const record = state.find(stack.Base) orelse return;
    if (stack.Top != record.Stack.Top) return;
    _ = state.cache(record);
}
