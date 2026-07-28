//! Contiguous Page Allocation

const common = @import("common");

const state = @import("mirai").pmm.state;

const address = @import("utils").address;
const bits = @import("utils").bits;

const AllocationError = common.errors.memory.allocation.AllocationError;
const sizes = common.constants.memory.sizes;

pub fn allocateContiguous(page_count: u64) AllocationError!u64 {
    if (page_count == 0) {
        return AllocationError.InvalidSize;
    }

    const pmm_state = state.getState();

    if (pmm_state.FreePages < page_count) {
        return AllocationError.OutOfMemory;
    }

    const start_page = bits.operations.findContiguousClear(
        pmm_state.Bitmap,
        0,
        pmm_state.TotalPages,
        page_count,
    ) orelse return AllocationError.OutOfMemory;

    bits.operations.setRange(pmm_state.Bitmap, start_page, page_count);
    pmm_state.FreePages -= page_count;
    pmm_state.UsedPages += page_count;

    return address.translate.pageToAddress(start_page);
}

pub fn allocateContiguousZeroed(page_count: u64) AllocationError!u64 {
    const physical_address = try allocateContiguous(page_count);
    const virtual_address = address.translate.physToVirt(physical_address);
    const total_bytes = page_count * sizes.PAGE_SIZE;
    const page_pointer: [*]u8 = @ptrFromInt(virtual_address);
    @memset(page_pointer[0..total_bytes], 0);
    return physical_address;
}

pub fn allocateAligned(page_count: u64, alignment_pages: u64) AllocationError!u64 {
    if (page_count == 0 or alignment_pages == 0) {
        return AllocationError.InvalidSize;
    }

    const pmm_state = state.getState();

    if (pmm_state.FreePages < page_count) {
        return AllocationError.OutOfMemory;
    }

    var search_start: u64 = 0;
    while (search_start + page_count <= pmm_state.TotalPages) {
        const aligned_start = (search_start + alignment_pages - 1) / alignment_pages * alignment_pages;

        if (aligned_start + page_count > pmm_state.TotalPages) {
            break;
        }

        var found = true;
        var check_index: u64 = 0;
        while (check_index < page_count) : (check_index += 1) {
            if (bits.operations.testBit(pmm_state.Bitmap, aligned_start + check_index)) {
                found = false;
                search_start = aligned_start + check_index + 1;
                break;
            }
        }

        if (found) {
            bits.operations.setRange(pmm_state.Bitmap, aligned_start, page_count);
            pmm_state.FreePages -= page_count;
            pmm_state.UsedPages += page_count;
            return address.translate.pageToAddress(aligned_start);
        }
    }

    return AllocationError.OutOfMemory;
}
