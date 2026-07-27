//! Range Page Free

const common = @import("common");

const bitmap = @import("../bitmap/bitmap.zig");
const state = @import("../state/state.zig");

const sizes = common.constants.memory.sizes;

pub fn freeRange(physical_address: u64, page_count: u64) void {
    if (page_count == 0) {
        return;
    }

    const start_page = physical_address >> sizes.PAGE_SHIFT;
    const pmm_state = state.getState();

    var freed_count: u64 = 0;
    var page_index: u64 = 0;

    while (page_index < page_count) : (page_index += 1) {
        const current_page = start_page + page_index;

        if (current_page >= pmm_state.TotalPages) {
            break;
        }

        if (bitmap.operations.testBit(pmm_state.Bitmap, current_page)) {
            bitmap.operations.clearBit(pmm_state.Bitmap, current_page);
            freed_count += 1;
        }
    }

    pmm_state.FreePages += freed_count;
    pmm_state.UsedPages -= freed_count;

    if (start_page < pmm_state.SearchStart) {
        pmm_state.SearchStart = start_page;
    }
}
