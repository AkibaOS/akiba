//! Range Page Free

const bitmap = @import("../bitmap/bitmap.zig");
const state = @import("../state.zig");

pub fn free_range(physical_address: u64, page_count: u64) void {
    if (page_count == 0) {
        return;
    }

    const start_page = physical_address >> 12;
    const pmm_state = state.get_state();

    var freed_count: u64 = 0;
    var page_index: u64 = 0;

    while (page_index < page_count) : (page_index += 1) {
        const current_page = start_page + page_index;

        if (current_page >= pmm_state.total_pages) {
            break;
        }

        if (bitmap.test_bit(pmm_state.bitmap, current_page)) {
            bitmap.clear_bit(pmm_state.bitmap, current_page);
            freed_count += 1;
        }
    }

    pmm_state.free_pages += freed_count;
    pmm_state.used_pages -= freed_count;

    if (start_page < pmm_state.search_start) {
        pmm_state.search_start = start_page;
    }
}
