//! Contiguous And Aligned Physical First-Fit Allocation

const address = @import("common").memory;
const common = @import("common");
const guard = @import("asm").interrupts.guard;
const state = @import("mirai").pmm.state;
const storage = @import("mirai").pmm.storage;

const sizes = common.constants.memory.sizes;
const AllocationError = common.errors.memory.allocation.AllocationError;

pub fn allocateContiguous(page_count: u64) AllocationError!u64 {
    return allocateAligned(page_count, 1);
}

pub fn allocateContiguousZeroed(page_count: u64) AllocationError!u64 {
    const physical_address = try allocateContiguous(page_count);
    const virtual_address = address.translate.physToVirt(physical_address);
    const total_bytes = page_count * sizes.PAGE_SIZE;
    const page_pointer: [*]u8 = @ptrFromInt(virtual_address);
    @memset(page_pointer[0..total_bytes], 0);
    return physical_address;
}

pub fn allocateAligned(page_count: u64, alignment_pages: u64) AllocationError!u64 {
    const previous_flags = guard.acquire();
    defer guard.release(previous_flags);
    if (page_count == 0 or alignment_pages == 0) return AllocationError.InvalidSize;
    const pmm_state = state.getState();
    if (pmm_state.Statistics.FreePages < page_count) return AllocationError.OutOfMemory;
    const index = pmm_state.Index;
    const page = storage.search.find(index, 0, index.PhysicalPages, page_count, alignment_pages) orelse
        return AllocationError.OutOfMemory;
    storage.access.assign(index, .{ .Start = page, .End = page + page_count }, .Allocated);
    pmm_state.Statistics.FreePages -= page_count;
    pmm_state.Statistics.UsedPages += page_count;
    return page * sizes.PAGE_SIZE;
}
