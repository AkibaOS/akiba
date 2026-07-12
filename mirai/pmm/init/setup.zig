//! Physical Memory Manager Setup

const bitmap_ops = @import("../bitmap/bitmap.zig");
const state = @import("../state.zig");
const types = @import("../types/types.zig");
const common = @import("root").common;

const memory_layout = common.constants.memory.layout;

pub fn initialize_from_memory_map(
    memory_map_entries: [*]const types.MemoryRegion,
    entry_count: u64,
    bitmap_location: u64,
) void {
    const pmm_state = state.get_state();

    var highest_address: u64 = 0;
    var entry_index: u64 = 0;
    while (entry_index < entry_count) : (entry_index += 1) {
        const region = memory_map_entries[entry_index];
        if (!region.is_usable()) continue;
        const region_end = region.end_address();
        if (region_end > highest_address) {
            highest_address = region_end;
        }
    }

    pmm_state.total_pages = highest_address >> 12;
    pmm_state.bitmap_size = (pmm_state.total_pages + 7) / 8;

    const bitmap_pointer: [*]u8 = @ptrFromInt(bitmap_location + memory_layout.physmap_base);
    pmm_state.bitmap = bitmap_pointer[0..pmm_state.bitmap_size];

    bitmap_ops.set_range(pmm_state.bitmap, 0, pmm_state.total_pages);
    pmm_state.free_pages = 0;
    pmm_state.used_pages = pmm_state.total_pages;

    entry_index = 0;
    while (entry_index < entry_count) : (entry_index += 1) {
        const region = memory_map_entries[entry_index];
        if (region.is_usable()) {
            mark_region_free(region.base_address, region.length);
        }
    }

    reserve_kernel_memory();
    reserve_bitmap_memory(bitmap_location);

    pmm_state.search_start = 0;
    pmm_state.initialized = true;
}

fn mark_region_free(base_address: u64, length: u64) void {
    const pmm_state = state.get_state();

    const start_page = (base_address + 4095) >> 12;
    const end_page = (base_address + length) >> 12;

    if (end_page <= start_page) {
        return;
    }

    const page_count = end_page - start_page;

    bitmap_ops.clear_range(pmm_state.bitmap, start_page, page_count);
    pmm_state.free_pages += page_count;
    pmm_state.used_pages -= page_count;
}

fn reserve_kernel_memory() void {
    const pmm_state = state.get_state();

    const kernel_start_page: u64 = 0;
    const kernel_end_page: u64 = 0x200;

    var page_index = kernel_start_page;
    while (page_index < kernel_end_page) : (page_index += 1) {
        if (!bitmap_ops.test_bit(pmm_state.bitmap, page_index)) {
            bitmap_ops.set_bit(pmm_state.bitmap, page_index);
            pmm_state.free_pages -= 1;
            pmm_state.used_pages += 1;
        }
    }
}

fn reserve_bitmap_memory(bitmap_location: u64) void {
    const pmm_state = state.get_state();

    const bitmap_start_page = bitmap_location >> 12;
    const bitmap_page_count = (pmm_state.bitmap_size + 4095) >> 12;

    var page_index: u64 = 0;
    while (page_index < bitmap_page_count) : (page_index += 1) {
        const current_page = bitmap_start_page + page_index;
        if (!bitmap_ops.test_bit(pmm_state.bitmap, current_page)) {
            bitmap_ops.set_bit(pmm_state.bitmap, current_page);
            pmm_state.free_pages -= 1;
            pmm_state.used_pages += 1;
        }
    }
}
