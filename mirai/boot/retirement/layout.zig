//! Loader Retirement Extents And Provenance Checks

const common = @import("common");
const conversion = @import("mirai").boot.regions.convert;
const limits = @import("shared").boot.constants.retirement;
const paging = @import("mirai").kagami.tables.walk;
const params = @import("shared").boot.types.params;
const pmm = @import("mirai").pmm;
const retirement = @import("shared").boot.types.retirement;
const types = @import("mirai").boot.types;
const walk = @import("mirai").boot.retirement.walk;

const address = common.constants.memory.layout;
const sizes = common.constants.memory.sizes;
const BootInfo = types.sequence.info.BootInfo;
const Ledger = retirement.Ledger;
const MemoryRegion = pmm.types.region.MemoryRegion;
const Range = pmm.types.storage.layout.Range;

pub fn pageRange(physical: u64, count: u64, limit: u64) ?Range {
    if (physical == 0 or physical & sizes.PAGE_MASK != 0 or physical >= limit or count == 0 or
        count > (limit - physical) / sizes.PAGE_SIZE) return null;
    const start = physical / sizes.PAGE_SIZE;
    return .{ .Start = start, .End = start + count };
}

pub fn canCompact(info: *const BootInfo, raw: types.retirement.footprint.RawMap) bool {
    const owned = info.Retirement orelse return false;
    if (!fixedGeometry(info)) return false;
    const fixed = owned.fixed();
    for (fixed) |range| {
        if (!conversion.ownsLoaderBacking(raw, range) or !aliases(info, range)) return false;
    }
    var remaining = owned.Tables.ChildFrames;
    var physical = owned.Tables.LedgerPhysical;
    while (remaining != 0) {
        const backing = pageRange(physical, 1, info.PhysmapSize) orelse return false;
        if (!outside(info, backing, &fixed) or !conversion.ownsLoaderBacking(raw, backing) or !aliases(info, backing)) return false;
        const node = ledger(physical);
        if (node.Count != chunkCount(remaining) or
            (physical == owned.Tables.LedgerPhysical and !mapWitness(node, owned))) return false;
        for (node.Frames[0..node.Count]) |frame| {
            const range = pageRange(frame, 1, info.PhysmapSize) orelse return false;
            if (!outside(info, range, &fixed) or !conversion.ownsLoaderBacking(raw, range)) return false;
        }
        remaining -= node.Count;
        physical = node.NextPhysical;
    }
    return physical == 0 and walk.exact(owned, info.PhysmapSize, .{ .Info = info, .Map = raw }, rawTable);
}

pub fn validate(info: *const BootInfo, index: ?pmm.types.storage.layout.Index) bool {
    const owned = info.Retirement orelse return false;
    if (!fixedGeometry(info) or !pmm.init.regions.validate(info.MemoryMap, info.PhysmapSize, &.{})) return false;
    const fixed = owned.fixed();
    for (fixed) |range| {
        if (!loaderBacked(info.MemoryMap, range)) return false;
    }
    var remaining = owned.Tables.ChildFrames;
    var physical = owned.Tables.LedgerPhysical;
    while (remaining != 0) {
        const backing = pageRange(physical, 1, info.PhysmapSize) orelse return false;
        if (!outside(info, backing, &fixed) or !loaderBacked(info.MemoryMap, backing)) return false;
        if (index) |current| {
            if (pmm.storage.access.read(current, backing.Start) != .Reserved) return false;
        }
        const node = ledger(physical);
        if (node.Count != chunkCount(remaining) or
            (physical == owned.Tables.LedgerPhysical and !mapWitness(node, owned))) return false;
        for (node.Frames[0..node.Count]) |frame| {
            const range = pageRange(frame, 1, info.PhysmapSize) orelse return false;
            if (!outside(info, range, &fixed) or !loaderBacked(info.MemoryMap, range)) return false;
        }
        remaining -= node.Count;
        physical = node.NextPhysical;
    }
    return physical == 0 and walk.exact(owned, info.PhysmapSize, info, loaderTable);
}

pub fn aliases(info: *const BootInfo, range: Range) bool {
    var page = range.Start;
    while (page < range.End) {
        const physical = page * sizes.PAGE_SIZE;
        const mapping = paging.lookupWithLimits(info.LoaderPML4Physical, address.PHYSMAP_BASE + physical, info.PhysmapSize, info.PhysmapSize) orelse return false;
        if (mapping.PhysicalAddress != physical or !mapping.Writable or mapping.UserAccessible) return false;
        const leaf_pages = mapping.PageSize / sizes.PAGE_SIZE;
        page += leaf_pages - page % leaf_pages;
    }
    return true;
}

fn rawTable(context: anytype, page: u64) bool {
    const range: Range = .{ .Start = page, .End = page + 1 };
    return outsideFixedData(context.Info, page) and conversion.ownsLoaderBacking(context.Map, range) and aliases(context.Info, range);
}

fn mapWitness(node: *const Ledger, owned: types.retirement.footprint.Footprint) bool {
    return node.MapPhysical == owned.Map.Start * sizes.PAGE_SIZE and node.MapPages == owned.Tables.MapPages;
}

pub fn ledger(physical: u64) *const Ledger {
    return @ptrFromInt(address.PHYSMAP_BASE + physical);
}

fn chunkCount(remaining: u64) u64 {
    return (remaining - 1) % limits.LEDGER_CAPACITY + 1;
}

fn fixedGeometry(info: *const BootInfo) bool {
    const owned = info.Retirement orelse return false;
    const page_limit = info.PhysmapSize / sizes.PAGE_SIZE;
    if (info.PhysmapBase != address.PHYSMAP_BASE or info.PhysmapSize == 0 or
        info.PhysmapSize > address.PHYSMAP_MAX_SIZE or info.PhysmapSize & sizes.PAGE_MASK != 0 or
        info.FramebufferPhysicalAddress >= info.PhysmapSize or info.FramebufferSize == 0 or
        info.FramebufferSize > info.PhysmapSize - info.FramebufferPhysicalAddress or
        info.KernelPhysicalBase >= info.KernelPhysicalEnd or info.KernelPhysicalEnd > info.PhysmapSize or
        info.LoaderPML4Physical & sizes.PAGE_MASK != 0 or
        owned.Root.Start != info.LoaderPML4Physical / sizes.PAGE_SIZE or owned.Root.Start >= page_limit or
        owned.Root.End != owned.Root.Start + 1 or owned.Tables.ChildFrames == 0 or owned.Tables.ChildFrames >= page_limit or
        owned.Tables.LedgerPhysical == 0) return false;
    const fixed = owned.fixed();
    for (fixed, 0..) |range, index| {
        if (range.Start >= range.End or range.End > page_limit or !outside(info, range, fixed[0..index])) return false;
    }
    return owned.Map.End - owned.Map.Start == owned.Tables.MapPages and
        owned.Stack.End - owned.Stack.Start == address.KERNEL_STACK_PAGES and
        owned.Parameters.End - owned.Parameters.Start == (@sizeOf(params.BootParams) + sizes.PAGE_MASK) / sizes.PAGE_SIZE;
}

pub fn retainedWindows(info: *const BootInfo) [2]Range {
    return .{
        pmm.init.regions.lowReservation(info.PhysmapSize / sizes.PAGE_SIZE),
        .{
            .Start = (info.FramebufferPhysicalAddress & ~sizes.LARGE_PAGE_MASK) / sizes.PAGE_SIZE,
            .End = @min(info.PhysmapSize, (info.FramebufferPhysicalAddress + info.FramebufferSize + sizes.LARGE_PAGE_MASK) & ~sizes.LARGE_PAGE_MASK) / sizes.PAGE_SIZE,
        },
    };
}

fn outside(info: *const BootInfo, candidate: Range, occupied: []const Range) bool {
    const image: Range = .{
        .Start = info.KernelPhysicalBase / sizes.PAGE_SIZE,
        .End = (info.KernelPhysicalEnd + sizes.PAGE_MASK) / sizes.PAGE_SIZE,
    };
    const framebuffer: Range = .{
        .Start = info.FramebufferPhysicalAddress / sizes.PAGE_SIZE,
        .End = (info.FramebufferPhysicalAddress + info.FramebufferSize + sizes.PAGE_MASK) / sizes.PAGE_SIZE,
    };
    if (overlap(candidate, image) or overlap(candidate, framebuffer)) return false;
    for (occupied) |range| {
        if (overlap(candidate, range)) return false;
    }
    return true;
}

fn outsideFixedData(info: *const BootInfo, page: u64) bool {
    const owned = info.Retirement.?;
    const fixed = [_]Range{ owned.Stack, owned.Parameters, owned.Map };
    return outside(info, .{ .Start = page, .End = page + 1 }, &fixed);
}

fn loaderTable(info: *const BootInfo, page: u64) bool {
    return outsideFixedData(info, page) and loaderBacked(info.MemoryMap, .{ .Start = page, .End = page + 1 });
}

fn loaderBacked(regions: []const MemoryRegion, range: Range) bool {
    var low: usize = 0;
    var high: usize = regions.len;
    const physical = range.Start * sizes.PAGE_SIZE;
    while (low < high) {
        const middle = low + (high - low) / 2;
        if (regions[middle].endAddress() <= physical) low = middle + 1 else high = middle;
    }
    var covered = range.Start;
    for (regions[low..]) |region| {
        if (region.RegionType != .LoaderData or region.BaseAddress / sizes.PAGE_SIZE > covered) return false;
        covered = region.endAddress() / sizes.PAGE_SIZE;
        if (covered >= range.End) return true;
    }
    return false;
}

fn overlap(left: Range, right: Range) bool {
    return left.Start < right.End and right.Start < left.End;
}
