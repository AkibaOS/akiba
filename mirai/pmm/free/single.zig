//! Single Page Free

const bitmap = @import("../bitmap/bitmap.zig");
const state = @import("../state.zig");

pub fn free_page(physical_address: u64) void {
    const page_index = physical_address >> 12;
    const pmm_state = state.get_state();

    if (page_index >= pmm_state.total_pages) {
        return;
    }

    if (!bitmap.test_bit(pmm_state.bitmap, page_index)) {
        return;
    }

    bitmap.clear_bit(pmm_state.bitmap, page_index);
    pmm_state.free_pages += 1;
    pmm_state.used_pages -= 1;

    if (page_index < pmm_state.search_start) {
        pmm_state.search_start = page_index;
    }
}
