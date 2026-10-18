//! Memory Phase

const bits = @import("utils").bits;
const common = @import("common");
const kalloc = @import("mirai").memory.kalloc;
const math = @import("utils").math;
const pmm = @import("mirai").pmm;
const print = @import("mirai").boot.sequence.print;
const strings = @import("mirai").boot.strings;
const types = @import("mirai").boot.types;
const zone = @import("mirai").memory.zone;

const kalloc_sizes = @import("mirai").memory.constants.kalloc.sizes;
const layout = common.constants.memory.layout;
const messages = strings.sequence.messages;
const status = strings.sequence.status;
const sizes = common.constants.memory.sizes;
const BootInfo = types.sequence.info.BootInfo;

pub fn prepare(boot_info: *const BootInfo) bool {
    print.phase(status.SYSTEM_MEMORY);
    if (boot_info.PhysmapBase != layout.PHYSMAP_BASE or boot_info.PhysmapSize == 0 or
        boot_info.PhysmapSize > layout.PHYSMAP_MAX_SIZE or (boot_info.PhysmapSize & sizes.PAGE_MASK) != 0 or
        boot_info.LoaderPML4Physical == 0 or (boot_info.LoaderPML4Physical & sizes.PAGE_MASK) != 0 or
        boot_info.LoaderPML4Physical > boot_info.PhysmapSize - sizes.PAGE_SIZE)
    {
        print.log(messages.INVALID_PHYSMAP, .{});
        return false;
    }
    const bitmap_location = findBitmapLocation(boot_info);
    if (bitmap_location == 0 or !pmm.init.setup.initializeFromMemoryMap(
        boot_info.MemoryMap,
        boot_info.MemoryMapCount,
        bitmap_location,
        boot_info.PhysmapSize,
    )) {
        print.log(messages.NO_BITMAP, .{});
        return false;
    }
    const framebuffer_start = math.integer.alignDown(boot_info.FramebufferPhysicalAddress, sizes.LARGE_PAGE_SIZE);
    const framebuffer_end = math.integer.alignUp(boot_info.FramebufferPhysicalAddress + boot_info.FramebufferSize, sizes.LARGE_PAGE_SIZE);
    pmm.init.setup.reservePhysicalRange(framebuffer_start, framebuffer_end - framebuffer_start);
    pmm.init.setup.reservePhysicalRange(boot_info.KernelPhysicalBase, boot_info.KernelPhysicalEnd - boot_info.KernelPhysicalBase);
    pmm.init.setup.reservePhysicalRange(boot_info.BootStackTop - layout.PHYSMAP_BASE - boot_info.BootStackSize, boot_info.BootStackSize);
    const statistics = pmm.state.getStatistics();
    print.log(messages.PHYSMAP_COVERAGE, .{boot_info.PhysmapSize / sizes.MEGABYTE});
    print.log(messages.BITMAP_STORAGE, .{ pmm.state.getState().BitmapSize, bitmap_location });
    print.log(messages.FOUND_PAGES, .{ statistics.TotalPages, statistics.TotalPages * sizes.PAGE_SIZE / sizes.MEGABYTE });
    print.log(messages.AVAILABLE, .{ statistics.FreePages, statistics.FreePages * sizes.PAGE_SIZE / sizes.MEGABYTE });
    return true;
}

pub fn finish(boot_info: *const BootInfo) bool {
    print.phase(status.ALLOCATOR);
    zone.bootstrap.init() catch {
        print.log(messages.NO_ZONES, .{});
        return false;
    };
    kalloc.init() catch {
        print.log(messages.NO_KALLOC, .{});
        return false;
    };
    print.log(messages.ALLOCATOR_READY, .{kalloc_sizes.ZONE_SIZES.len});
    print.phase(status.KAGAMI);
    print.log(messages.PML4, .{boot_info.PML4Physical});
    print.phase(status.KERNEL_MEMORY);
    print.log(messages.STACK_INFO, .{ boot_info.BootStackTop - boot_info.BootStackSize, boot_info.BootStackTop });
    return true;
}

fn findBitmapLocation(boot_info: *const BootInfo) u64 {
    const page_count = pmm.init.setup.managedPageCount(boot_info.MemoryMap, boot_info.MemoryMapCount, boot_info.PhysmapSize);
    const bitmap_span = math.integer.alignUp(bits.operations.bitmapBytes(page_count), sizes.PAGE_SIZE);
    if (bitmap_span == 0) return 0;
    const reserved_end = pmm.constants.limits.KERNEL_RESERVED_PAGES * sizes.PAGE_SIZE;
    const framebuffer_start = math.integer.alignDown(boot_info.FramebufferPhysicalAddress, sizes.LARGE_PAGE_SIZE);
    const framebuffer_end = math.integer.alignUp(boot_info.FramebufferPhysicalAddress + boot_info.FramebufferSize, sizes.LARGE_PAGE_SIZE);
    var index: u64 = 0;
    while (index < boot_info.MemoryMapCount) : (index += 1) {
        const region = boot_info.MemoryMap[index];
        if (!region.isUsable() or region.BaseAddress >= boot_info.PhysmapSize) continue;
        const end = math.integer.alignDown(region.BaseAddress + @min(region.Length, boot_info.PhysmapSize - region.BaseAddress), sizes.PAGE_SIZE);
        var candidate = math.integer.alignUp(@max(region.BaseAddress, reserved_end), sizes.PAGE_SIZE);
        while (candidate < end and bitmap_span <= end - candidate) {
            if (candidate < boot_info.KernelPhysicalEnd and boot_info.KernelPhysicalBase < candidate + bitmap_span) {
                candidate = boot_info.KernelPhysicalEnd;
                continue;
            }
            if (candidate < framebuffer_end and framebuffer_start < candidate + bitmap_span) {
                candidate = framebuffer_end;
                continue;
            }
            return candidate;
        }
    }
    return 0;
}
