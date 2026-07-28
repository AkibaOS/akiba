//! Single Page Allocation

const common = @import("common");

const bitmap = @import("mirai").pmm.bitmap;
const state = @import("mirai").pmm.state;

const AllocationError = common.errors.memory.allocation.AllocationError;
const layout = common.constants.memory.layout;
const sizes = common.constants.memory.sizes;

pub fn allocatePage() AllocationError!u64 {
    const pmm_state = state.getState();

    if (pmm_state.FreePages == 0) {
        return AllocationError.OutOfMemory;
    }

    const page_index = bitmap.operations.findFirstClear(
        pmm_state.Bitmap,
        pmm_state.SearchStart,
        pmm_state.TotalPages,
    ) orelse bitmap.operations.findFirstClear(
        pmm_state.Bitmap,
        0,
        pmm_state.SearchStart,
    ) orelse return AllocationError.OutOfMemory;

    bitmap.operations.setBit(pmm_state.Bitmap, page_index);
    pmm_state.FreePages -= 1;
    pmm_state.UsedPages += 1;
    pmm_state.SearchStart = page_index + 1;

    return page_index << sizes.PAGE_SHIFT;
}

pub fn allocatePageZeroed() AllocationError!u64 {
    const physical_address = try allocatePage();
    const virtual_address = physical_address + layout.PHYSMAP_BASE;
    const page_pointer: [*]u8 = @ptrFromInt(virtual_address);
    @memset(page_pointer[0..sizes.PAGE_SIZE], 0);
    return physical_address;
}
