//! Single Page Free

const state = @import("mirai").pmm.state;

const bits = @import("utils").bits;

const address = @import("utils").address;

pub fn freePage(physical_address: u64) void {
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
