//! Contiguous Page Allocation

const bitmap = @import("../bitmap/bitmap.zig");
const state = @import("../state.zig");
const common = @import("../../../common/common.zig");

const AllocationError = common.errors.memory.AllocationError;

pub fn allocate_contiguous(page_count: u64) AllocationError!u64 {
    if (page_count == 0) {
        return AllocationError.InvalidSize;
    }

    const pmm_state = state.get_state();

    if (pmm_state.free_pages < page_count) {
        return AllocationError.OutOfMemory;
    }

    const start_page = bitmap.find_contiguous_clear(
        pmm_state.bitmap,
        0,
        pmm_state.total_pages,
        page_count,
    ) orelse return AllocationError.OutOfMemory;

    bitmap.set_range(pmm_state.bitmap, start_page, page_count);
    pmm_state.free_pages -= page_count;
    pmm_state.used_pages += page_count;

    return start_page << 12;
}

pub fn allocate_contiguous_zeroed(page_count: u64) AllocationError!u64 {
    const physical_address = try allocate_contiguous(page_count);
    const virtual_address = physical_address + common.constants.memory.layout.physmap_base;
    const total_bytes = page_count * 4096;
    const page_ptr: [*]u8 = @ptrFromInt(virtual_address);
    @memset(page_ptr[0..total_bytes], 0);
    return physical_address;
}

pub fn allocate_aligned(page_count: u64, alignment_pages: u64) AllocationError!u64 {
    if (page_count == 0 or alignment_pages == 0) {
        return AllocationError.InvalidSize;
    }

    const pmm_state = state.get_state();

    if (pmm_state.free_pages < page_count) {
        return AllocationError.OutOfMemory;
    }

    var search_start: u64 = 0;
    while (search_start + page_count <= pmm_state.total_pages) {
        const aligned_start = (search_start + alignment_pages - 1) / alignment_pages * alignment_pages;

        if (aligned_start + page_count > pmm_state.total_pages) {
            break;
        }

        var found = true;
        var check_index: u64 = 0;
        while (check_index < page_count) : (check_index += 1) {
            if (bitmap.test_bit(pmm_state.bitmap, aligned_start + check_index)) {
                found = false;
                search_start = aligned_start + check_index + 1;
                break;
            }
        }

        if (found) {
            bitmap.set_range(pmm_state.bitmap, aligned_start, page_count);
            pmm_state.free_pages -= page_count;
            pmm_state.used_pages += page_count;
            return aligned_start << 12;
        }
    }

    return AllocationError.OutOfMemory;
}
