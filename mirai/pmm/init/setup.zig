//! Physical Memory Manager Setup

const address = @import("utils").address;
const bits = @import("utils").bits;
const common = @import("common");
const constants = @import("mirai").pmm.constants;
const math = @import("utils").math;
const state = @import("mirai").pmm.state;
const types = @import("mirai").pmm.types;

const sizes = common.constants.memory.sizes;

pub fn managedPageCount(
    memory_map_entries: [*]const types.region.MemoryRegion,
    entry_count: u64,
    physical_limit: u64,
) u64 {
    const limit = math.integer.alignDown(@min(physical_limit, constants.limits.MAX_PHYSICAL_MEMORY), sizes.PAGE_SIZE);
    var highest_address: u64 = 0;
    var entry_index: u64 = 0;
    while (entry_index < entry_count) : (entry_index += 1) {
        const region = memory_map_entries[entry_index];
        if (!region.isUsable() or region.BaseAddress >= limit) continue;
        const start = math.integer.alignUp(region.BaseAddress, sizes.PAGE_SIZE);
        const end = math.integer.alignDown(region.BaseAddress + @min(region.Length, limit - region.BaseAddress), sizes.PAGE_SIZE);
        if (end > start) highest_address = @max(highest_address, end);
    }
    return address.translate.addressToPage(highest_address);
}

pub fn initializeFromMemoryMap(
    memory_map_entries: [*]const types.region.MemoryRegion,
    entry_count: u64,
    bitmap_location: u64,
    physical_limit: u64,
) bool {
    if (physical_limit == 0 or physical_limit > constants.limits.MAX_PHYSICAL_MEMORY or
        (physical_limit & sizes.PAGE_MASK) != 0 or bitmap_location == 0 or
        (bitmap_location & sizes.PAGE_MASK) != 0)
    {
        return false;
    }
    const total_pages = managedPageCount(memory_map_entries, entry_count, physical_limit);
    if (total_pages == 0) return false;
    const bitmap_size = bits.operations.bitmapBytes(total_pages);
    const bitmap_span = math.integer.alignUp(bitmap_size, sizes.PAGE_SIZE);
    const managed_end = total_pages * sizes.PAGE_SIZE;
    if (bitmap_location >= managed_end or bitmap_span > managed_end - bitmap_location) return false;

    var bitmap_available = false;
    var entry_index: u64 = 0;
    while (entry_index < entry_count) : (entry_index += 1) {
        const region = memory_map_entries[entry_index];
        if (!region.isUsable() or region.BaseAddress > bitmap_location) continue;
        const end = region.BaseAddress + @min(region.Length, managed_end - region.BaseAddress);
        if (bitmap_location <= end and bitmap_span <= end - bitmap_location) {
            bitmap_available = true;
            break;
        }
    }
    if (!bitmap_available) return false;

    const pmm_state = state.getState();
    pmm_state.TotalPages = total_pages;
    pmm_state.BitmapSize = bitmap_size;
    const bitmap_pointer: [*]u8 = @ptrFromInt(address.translate.physToVirt(bitmap_location));
    pmm_state.Bitmap = bitmap_pointer[0..bitmap_size];
    @memset(pmm_state.Bitmap, constants.limits.BITMAP_ALL_USED);
    pmm_state.FreePages = 0;
    pmm_state.UsedPages = total_pages;
    pmm_state.ReservedPages = 0;
    pmm_state.WiredPages = 0;

    entry_index = 0;
    while (entry_index < entry_count) : (entry_index += 1) {
        const region = memory_map_entries[entry_index];
        if (region.isUsable()) markRegionFree(region.BaseAddress, region.Length);
    }
    reservePages(0, constants.limits.KERNEL_RESERVED_PAGES);
    reservePages(address.translate.addressToPage(bitmap_location), bitmap_span / sizes.PAGE_SIZE);
    pmm_state.SearchStart = 0;
    pmm_state.Initialized = true;
    return true;
}

pub fn reservePhysicalRange(base_address: u64, length: u64) void {
    const pmm_state = state.getState();
    const limit = pmm_state.TotalPages * sizes.PAGE_SIZE;
    if (!pmm_state.Initialized or length == 0 or base_address >= limit) return;
    const end = base_address + @min(length, limit - base_address);
    const start_page = address.translate.addressToPage(base_address);
    const end_page = math.integer.divideCeil(end, sizes.PAGE_SIZE);
    reservePages(start_page, end_page - start_page);
}

fn markRegionFree(base_address: u64, length: u64) void {
    const pmm_state = state.getState();
    const limit = pmm_state.TotalPages * sizes.PAGE_SIZE;
    if (base_address >= limit) return;
    const start_page = math.integer.divideCeil(base_address, sizes.PAGE_SIZE);
    const end_page = address.translate.addressToPage(base_address + @min(length, limit - base_address));
    var page_index = start_page;
    while (page_index < end_page) : (page_index += 1) {
        if (bits.operations.testBit(pmm_state.Bitmap, page_index)) {
            bits.operations.clearBit(pmm_state.Bitmap, page_index);
            pmm_state.FreePages += 1;
            pmm_state.UsedPages -= 1;
        }
    }
}

fn reservePages(start_page: u64, page_count: u64) void {
    const pmm_state = state.getState();
    if (start_page >= pmm_state.TotalPages) return;
    const end_page = start_page + @min(page_count, pmm_state.TotalPages - start_page);
    var page_index = start_page;
    while (page_index < end_page) : (page_index += 1) {
        if (!bits.operations.testBit(pmm_state.Bitmap, page_index)) {
            bits.operations.setBit(pmm_state.Bitmap, page_index);
            pmm_state.FreePages -= 1;
            pmm_state.UsedPages += 1;
        }
    }
}
