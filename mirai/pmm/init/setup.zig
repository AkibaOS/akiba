//! Physical Memory Manager Setup

const common = @import("common");

const constants = @import("mirai").pmm.constants;
const state = @import("mirai").pmm.state;
const types = @import("mirai").pmm.types;

const address = @import("utils").address;
const bits = @import("utils").bits;
const math = @import("utils").math;

const sizes = common.constants.memory.sizes;

pub fn initializeFromMemoryMap(
    memory_map_entries: [*]const types.region.MemoryRegion,
    entry_count: u64,
    bitmap_location: u64,
) void {
    const pmm_state = state.getState();

    var highest_address: u64 = 0;
    var entry_index: u64 = 0;
    while (entry_index < entry_count) : (entry_index += 1) {
        const region = memory_map_entries[entry_index];
        if (!region.isUsable()) continue;
        const region_end = region.endAddress();
        if (region_end > highest_address) {
            highest_address = region_end;
        }
    }

    pmm_state.TotalPages = address.translate.addressToPage(highest_address);
    pmm_state.BitmapSize = bits.operations.bitmapBytes(pmm_state.TotalPages);

    const bitmap_pointer: [*]u8 = @ptrFromInt(address.translate.physToVirt(bitmap_location));
    pmm_state.Bitmap = bitmap_pointer[0..pmm_state.BitmapSize];

    bits.operations.setRange(pmm_state.Bitmap, 0, pmm_state.TotalPages);
    pmm_state.FreePages = 0;
    pmm_state.UsedPages = pmm_state.TotalPages;

    entry_index = 0;
    while (entry_index < entry_count) : (entry_index += 1) {
        const region = memory_map_entries[entry_index];
        if (region.isUsable()) {
            markRegionFree(region.BaseAddress, region.Length);
        }
    }

    reserveKernelMemory();
    reserveBitmapMemory(bitmap_location);

    pmm_state.SearchStart = 0;
    pmm_state.Initialized = true;
}

fn markRegionFree(base_address: u64, length: u64) void {
    const pmm_state = state.getState();

    const start_page = math.integer.divideCeil(base_address, sizes.PAGE_SIZE);
    const end_page = address.translate.addressToPage(base_address + length);

    if (end_page <= start_page) {
        return;
    }

    const page_count = end_page - start_page;

    bits.operations.clearRange(pmm_state.Bitmap, start_page, page_count);
    pmm_state.FreePages += page_count;
    pmm_state.UsedPages -= page_count;
}

fn reserveKernelMemory() void {
    const pmm_state = state.getState();

    var page_index: u64 = 0;
    while (page_index < constants.limits.KERNEL_RESERVED_PAGES) : (page_index += 1) {
        if (!bits.operations.testBit(pmm_state.Bitmap, page_index)) {
            bits.operations.setBit(pmm_state.Bitmap, page_index);
            pmm_state.FreePages -= 1;
            pmm_state.UsedPages += 1;
        }
    }
}

fn reserveBitmapMemory(bitmap_location: u64) void {
    const pmm_state = state.getState();

    const bitmap_start_page = address.translate.addressToPage(bitmap_location);
    const bitmap_page_count = math.integer.divideCeil(pmm_state.BitmapSize, sizes.PAGE_SIZE);

    var page_index: u64 = 0;
    while (page_index < bitmap_page_count) : (page_index += 1) {
        const current_page = bitmap_start_page + page_index;
        if (!bits.operations.testBit(pmm_state.Bitmap, current_page)) {
            bits.operations.setBit(pmm_state.Bitmap, current_page);
            pmm_state.FreePages -= 1;
            pmm_state.UsedPages += 1;
        }
    }
}
