//! Checked Physical Range Release

const common = @import("common");
const guard = @import("asm").interrupts.guard;
const state = @import("mirai").pmm.state;
const storage = @import("mirai").pmm.storage;
const types = @import("mirai").pmm.types;

const sizes = common.constants.memory.sizes;

pub fn freeRange(physical: u64, page_count: u64) void {
    _ = releaseRange(physical, page_count);
}

pub fn releaseRange(physical: u64, page_count: u64) bool {
    const previous_flags = guard.acquire();
    defer guard.release(previous_flags);
    return releaseFrom(state.getState(), physical, page_count);
}

pub fn releaseFrom(pmm_state: *types.state.allocator.State, physical: u64, page_count: u64) bool {
    const index = pmm_state.Index;
    const page = physical / sizes.PAGE_SIZE;
    if (physical & sizes.PAGE_MASK != 0 or page_count == 0 or page >= index.PhysicalPages or
        page_count > index.PhysicalPages - page or page_count > pmm_state.Statistics.UsedPages) return false;
    const end = page + page_count;
    if (!storage.access.matches(index, page, end, .Allocated)) return false;
    storage.access.assign(index, .{ .Start = page, .End = end }, .Free);
    pmm_state.Statistics.FreePages += page_count;
    pmm_state.Statistics.UsedPages -= page_count;
    pmm_state.SearchStart = @min(pmm_state.SearchStart, page);
    return true;
}
