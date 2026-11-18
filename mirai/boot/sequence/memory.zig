//! Memory Phase

const common = @import("common");
const heap = @import("mirai").memory.heap;
const kalloc = @import("mirai").memory.kalloc;
const math = @import("utils").math;
const options = @import("options");
const pmm = @import("mirai").pmm;
const print = @import("mirai").boot.sequence.print;
const rootchecks = if (options.GUEST_CHECKS) @import("tests").guest.support.root else null;
const stack = @import("mirai").memory.stack;
const strings = @import("mirai").boot.strings;
const types = @import("mirai").boot.types;
const zone = @import("mirai").memory.zone;

const kalloc_sizes = @import("mirai").memory.constants.kalloc.sizes;
const layout = common.constants.memory.layout;
const messages = strings.sequence.messages;
const sizes = common.constants.memory.sizes;
const status = strings.sequence.status;
const BootInfo = types.sequence.info.BootInfo;
const MemoryRegion = pmm.types.region.MemoryRegion;
const Range = pmm.types.storage.Range;

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
    if (!initializePMM(boot_info)) {
        print.log(messages.NO_PMM, .{});
        return false;
    }
    if (options.GUEST_CHECKS) @call(.never_inline, rootchecks.checkZoneRollback, .{});
    zone.bootstrap.init() catch {
        print.log(messages.NO_ZONES, .{});
        return false;
    };
    const statistics = pmm.state.getStatistics();
    print.log(messages.PHYSMAP_COVERAGE, .{boot_info.PhysmapSize / sizes.MEGABYTE});
    print.log(messages.PMM_STORAGE, .{ statistics.MetadataBytes, statistics.MetadataPages });
    print.log(messages.MANAGED_PAGES, .{ statistics.TotalPages, statistics.totalBytes() / sizes.MEGABYTE, statistics.ReservedPages });
    print.log(messages.AVAILABLE, .{ statistics.FreePages, statistics.freeBytes() / sizes.MEGABYTE });
    return true;
}

pub fn finish(boot_info: *const BootInfo) bool {
    print.phase(status.ALLOCATOR);
    heap.state.initialize() catch {
        print.log(messages.NO_HEAP, .{});
        return false;
    };
    stack.state.initialize() catch {
        print.log(messages.NO_STACK_STORAGE, .{});
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

fn initializePMM(info: *const BootInfo) bool {
    const limit = info.PhysmapSize;
    const map_address = @intFromPtr(info.MemoryMap);
    if (map_address < layout.PHYSMAP_BASE or map_address % @alignOf(MemoryRegion) != 0 or
        info.BootStackTop < layout.PHYSMAP_BASE or info.BootStackSize == 0 or
        info.KernelPhysicalBase >= info.KernelPhysicalEnd or info.KernelPhysicalEnd > limit or
        info.FramebufferSize == 0 or info.FramebufferPhysicalAddress >= limit or
        info.FramebufferSize > limit - info.FramebufferPhysicalAddress) return false;
    const map_start = map_address - layout.PHYSMAP_BASE;
    const stack_end = info.BootStackTop - layout.PHYSMAP_BASE;
    if (map_start >= limit or info.MemoryMapCount == 0 or
        info.MemoryMapCount > (limit - map_start) / @sizeOf(MemoryRegion) or
        stack_end > limit or info.BootStackSize > stack_end) return false;
    const exclusions = [_]Range{
        roundedRange(info.KernelPhysicalBase, info.KernelPhysicalEnd, sizes.PAGE_SIZE, limit),
        roundedRange(stack_end - info.BootStackSize, stack_end, sizes.PAGE_SIZE, limit),
        roundedRange(info.FramebufferPhysicalAddress, info.FramebufferPhysicalAddress + info.FramebufferSize, sizes.LARGE_PAGE_SIZE, limit),
        roundedRange(map_start, map_start + info.MemoryMapCount * @sizeOf(MemoryRegion), sizes.PAGE_SIZE, limit),
        roundedRange(info.LoaderPML4Physical, info.LoaderPML4Physical + sizes.PAGE_SIZE, sizes.PAGE_SIZE, limit),
    };
    return pmm.init.setup.initializeFromMemoryMap(info.MemoryMap[0..info.MemoryMapCount], limit, &exclusions);
}

fn roundedRange(start: u64, end: u64, alignment: u64, limit: u64) Range {
    return .{
        .Start = math.integer.alignDown(start, alignment) / sizes.PAGE_SIZE,
        .End = @min(limit, math.integer.alignUp(end, alignment)) / sizes.PAGE_SIZE,
    };
}
