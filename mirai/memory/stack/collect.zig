//! Kernel Stack Backing And Virtual Range Collection

const guard = @import("asm").interrupts.guard;
const kagami = @import("mirai").kagami;
const limits = @import("mirai").memory.constants.stack.limits;
const mapping = @import("mirai").memory.stack.mapping;
const state = @import("mirai").memory.stack.state;

pub fn collect() u64 {
    const flags = guard.acquire();
    defer guard.release(flags);
    if (!kagami.state.hasOwnedKernel()) return 0;
    var released_pages: u64 = 0;
    while (state.getState().FreeCount > limits.CACHE_TARGET) {
        const cached = state.getState().FreeList orelse break;
        if (!mapping.validate(cached)) break;
        const record = state.takeCached() orelse break;
        const pages = record.PageCount;
        mapping.unwind(record);
        state.discard(record);
        released_pages += pages;
    }
    return released_pages;
}
