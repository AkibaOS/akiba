//! Single Page Free

const address = @import("utils").address;
const bits = @import("utils").bits;
const guard = @import("asm").interrupts.guard;
const state = @import("mirai").pmm.state;

pub fn freePage(physical_address: u64) void {
    const previous_flags = guard.acquire();
    defer guard.release(previous_flags);

    const page_index = address.translate.addressToPage(physical_address);
    const pmm_state = state.getState();

    if (page_index >= pmm_state.TotalPages) {
        return;
    }

    if (!bits.operations.testBit(pmm_state.Bitmap, page_index)) {
        return;
    }

    bits.operations.clearBit(pmm_state.Bitmap, page_index);
    pmm_state.FreePages += 1;
    pmm_state.UsedPages -= 1;

    if (page_index < pmm_state.SearchStart) {
        pmm_state.SearchStart = page_index;
    }
}
