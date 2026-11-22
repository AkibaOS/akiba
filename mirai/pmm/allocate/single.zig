//! Single Page Next-Fit Allocation

const address = @import("common").memory;
const checks = if (options.GUEST_CHECKS) @import("tests").guest.support.allocation else null;
const common = @import("common");
const guard = @import("asm").interrupts.guard;
const options = @import("options");
const state = @import("mirai").pmm.state;
const storage = @import("mirai").pmm.storage;

const sizes = common.constants.memory.sizes;
const AllocationError = common.errors.memory.allocation.AllocationError;

pub fn allocatePage() AllocationError!u64 {
    const previous_flags = guard.acquire();
    defer guard.release(previous_flags);
    const pmm_state = state.getState();
    if (pmm_state.Statistics.FreePages == 0) return AllocationError.OutOfMemory;
    const index = pmm_state.Index;
    const cursor = @min(pmm_state.SearchStart, index.PhysicalPages);
    const page = storage.search.find(index, cursor, index.PhysicalPages, 1, 1) orelse
        storage.search.find(index, 0, cursor, 1, 1) orelse return AllocationError.OutOfMemory;
    if (options.GUEST_CHECKS) try checks.before();
    storage.access.assign(index, .{ .Start = page, .End = page + 1 }, .Allocated);
    pmm_state.Statistics.FreePages -= 1;
    pmm_state.Statistics.UsedPages += 1;
    pmm_state.SearchStart = page + 1;
    return page * sizes.PAGE_SIZE;
}

pub fn allocatePageZeroed() AllocationError!u64 {
    const physical_address = try allocatePage();
    const virtual_address = address.translate.physToVirt(physical_address);
    const page_pointer: [*]u8 = @ptrFromInt(virtual_address);
    @memset(page_pointer[0..sizes.PAGE_SIZE], 0);
    return physical_address;
}
