//! Single Page Allocation

const address = @import("utils").address;
const bits = @import("utils").bits;
const common = @import("common");
const guard = @import("asm").interrupts.guard;
const state = @import("mirai").pmm.state;

const sizes = common.constants.memory.sizes;

const AllocationError = common.errors.memory.allocation.AllocationError;

pub fn allocatePage() AllocationError!u64 {
    const previous_flags = guard.acquire();
    defer guard.release(previous_flags);

    const pmm_state = state.getState();

    if (pmm_state.FreePages == 0) {
        return AllocationError.OutOfMemory;
    }

    const page_index = bits.operations.findFirstClear(
        pmm_state.Bitmap,
        pmm_state.SearchStart,
        pmm_state.TotalPages,
    ) orelse bits.operations.findFirstClear(
        pmm_state.Bitmap,
        0,
        pmm_state.SearchStart,
    ) orelse return AllocationError.OutOfMemory;

    bits.operations.setBit(pmm_state.Bitmap, page_index);
    pmm_state.FreePages -= 1;
    pmm_state.UsedPages += 1;
    pmm_state.SearchStart = page_index + 1;

    return address.translate.pageToAddress(page_index);
}

pub fn allocatePageZeroed() AllocationError!u64 {
    const physical_address = try allocatePage();
    const virtual_address = address.translate.physToVirt(physical_address);
    const page_pointer: [*]u8 = @ptrFromInt(virtual_address);
    @memset(page_pointer[0..sizes.PAGE_SIZE], 0);
    return physical_address;
}
