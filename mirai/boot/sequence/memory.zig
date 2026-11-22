//! Memory Phase

const common = @import("common");
const cpu = @import("asm").cpu;
const heap = @import("mirai").memory.heap;
const kagami = @import("mirai").kagami;
const kalloc = @import("mirai").memory.kalloc;
const math = @import("common").math;
const options = @import("options");
const pmm = @import("mirai").pmm;
const print = @import("mirai").boot.sequence.print;
const retirement = @import("mirai").boot.retirement;
const rootchecks = if (options.GUEST_CHECKS) @import("tests").guest.support.root else null;
const stack = @import("mirai").memory.stack;
const strings = @import("mirai").boot.strings;
const tss = @import("mirai").boot.tss;
const types = @import("mirai").boot.types;
const zone = @import("mirai").memory.zone;

const kalloc_sizes = @import("mirai").memory.constants.kalloc.sizes;
const layout = common.constants.memory.layout;
const messages = strings.sequence.messages;
const sizes = common.constants.memory.sizes;
const status = strings.sequence.status;
const BootInfo = types.sequence.info.BootInfo;
const Range = pmm.types.storage.layout.Range;

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

pub fn retireLoader(info: *const BootInfo) ?u64 {
    const stack_pointer = cpu.state.readStackPointer();
    const active_root = kagami.activate.getActivePML4();
    if (cpu.state.readFlags() & cpu.constants.control.registers.RFLAGS_INTERRUPT_ENABLE != 0 or
        !kagami.state.hasOwnedKernel() or kagami.state.getCurrentKagami() != kagami.state.getKernelKagami() or
        active_root != info.PML4Physical or active_root == info.LoaderPML4Physical or
        info.BootStackSize > info.BootStackTop or stack_pointer < info.BootStackTop - info.BootStackSize or
        stack_pointer >= info.BootStackTop or tss.state.getBootTSS().RSP0 != info.BootStackTop) return null;
    return retirement.release.from(pmm.state.getState(), info);
}

fn initializePMM(info: *const BootInfo) bool {
    if (!retirement.layout.validate(info, null)) return false;
    const owned = info.Retirement.?;
    const limit = info.PhysmapSize;
    const exclusions = [_]Range{
        roundedRange(info.KernelPhysicalBase, info.KernelPhysicalEnd, sizes.PAGE_SIZE, limit),
        roundedRange(info.FramebufferPhysicalAddress, info.FramebufferPhysicalAddress + info.FramebufferSize, sizes.LARGE_PAGE_SIZE, limit),
    } ++ owned.fixed();
    return pmm.init.setup.initializeFromMemoryMap(info.MemoryMap, limit, &exclusions);
}

fn roundedRange(start: u64, end: u64, alignment: u64, limit: u64) Range {
    return .{
        .Start = math.integer.alignDown(start, alignment) / sizes.PAGE_SIZE,
        .End = @min(limit, math.integer.alignUp(end, alignment)) / sizes.PAGE_SIZE,
    };
}
