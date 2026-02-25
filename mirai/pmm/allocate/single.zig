//! Single Page Allocation

const bitmap = @import("../bitmap/bitmap.zig");
const state = @import("../state.zig");
const common = @import("../../../common/common.zig");

const AllocationError = common.errors.memory.AllocationError;

pub fn allocate_page() AllocationError!u64 {
    const pmm_state = state.get_state();

    if (pmm_state.free_pages == 0) {
        return AllocationError.OutOfMemory;
    }

    const page_index = bitmap.find_first_clear(
        pmm_state.bitmap,
        pmm_state.search_start,
        pmm_state.total_pages,
    ) orelse bitmap.find_first_clear(
        pmm_state.bitmap,
        0,
        pmm_state.search_start,
    ) orelse return AllocationError.OutOfMemory;

    bitmap.set_bit(pmm_state.bitmap, page_index);
    pmm_state.free_pages -= 1;
    pmm_state.used_pages += 1;
    pmm_state.search_start = page_index + 1;

    return page_index << 12;
}

pub fn allocate_page_zeroed() AllocationError!u64 {
    const physical_address = try allocate_page();
    const virtual_address = physical_address + common.constants.memory.layout.physmap_base;
    const page_ptr: [*]u8 = @ptrFromInt(virtual_address);
    @memset(page_ptr[0..4096], 0);
    return physical_address;
}
