//! Single Page Free

const common = @import("common");

const bitmap = @import("mirai").pmm.bitmap;
const state = @import("mirai").pmm.state;

const sizes = common.constants.memory.sizes;

pub fn freePage(physical_address: u64) void {
    const page_index = physical_address >> sizes.PAGE_SHIFT;
    const pmm_state = state.getState();

    if (page_index >= pmm_state.TotalPages) {
        return;
    }

    if (!bitmap.operations.testBit(pmm_state.Bitmap, page_index)) {
        return;
    }

    bitmap.operations.clearBit(pmm_state.Bitmap, page_index);
    pmm_state.FreePages += 1;
    pmm_state.UsedPages -= 1;

    if (page_index < pmm_state.SearchStart) {
        pmm_state.SearchStart = page_index;
    }
}
