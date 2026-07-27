//! Zone Allocation

const common = @import("common");

const bootstrap = @import("bootstrap.zig");
const convert = @import("../convert/convert.zig");
const pmm = @import("../../pmm/pmm.zig");
const types = @import("../types/types.zig");

const sizes = common.constants.memory.sizes;

const AllocationError = common.errors.memory.allocation.AllocationError;
const FreeElement = types.zone.FreeElement;
const Zone = types.zone.Zone;
const ZonePageMeta = types.zone.ZonePageMeta;

pub fn zalloc(zone: *Zone) AllocationError!*anyopaque {
    if (zone.PartialPages == null) {
        try expand(zone);
    }

    const page = zone.PartialPages orelse return AllocationError.OutOfMemory;
    const element = page.FreeList orelse return AllocationError.OutOfMemory;

    page.FreeList = element.Next;
    page.InUse += 1;
    zone.AllocationCount += 1;

    if (page.FreeList == null) {
        zone.PartialPages = page.Next;
        page.Next = zone.FullPages;
        zone.FullPages = page;
    }

    return @ptrCast(element);
}

pub fn zallocZeroed(zone: *Zone) AllocationError!*anyopaque {
    const pointer = try zalloc(zone);
    const bytes: [*]u8 = @ptrCast(pointer);
    @memset(bytes[0..zone.ElementSize], 0);
    return pointer;
}

pub fn zfree(zone: *Zone, pointer: *anyopaque) void {
    const page_virtual = @intFromPtr(pointer) & ~@as(usize, sizes.PAGE_MASK);
    const page = findPage(zone, page_virtual) orelse return;
    const was_full = (page.FreeList == null);

    const element: *FreeElement = @ptrCast(@alignCast(pointer));
    element.Next = page.FreeList;
    page.FreeList = element;
    page.InUse -|= 1;
    zone.FreeCount += 1;

    if (was_full) {
        removeFromFull(zone, page);
        page.Next = zone.PartialPages;
        zone.PartialPages = page;
    }
}

fn expand(zone: *Zone) AllocationError!void {
    const physical = pmm.allocate.single.allocatePage() catch return AllocationError.OutOfMemory;
    const virtual = convert.physToVirt(physical);

    const page_meta_zone = bootstrap.getPageMetaZone();
    const meta_pointer = zalloc(page_meta_zone) catch {
        pmm.free.single.freePage(physical);
        return AllocationError.OutOfMemory;
    };
    const meta: *ZonePageMeta = @ptrCast(@alignCast(meta_pointer));

    meta.Zone = zone;
    meta.PagePhysical = physical;
    meta.PageVirtual = virtual;
    meta.FreeList = null;
    meta.InUse = 0;
    meta.Next = zone.PartialPages;
    zone.PartialPages = meta;
    zone.PageCount += 1;

    const base: [*]u8 = @ptrFromInt(virtual);
    var offset: usize = 0;
    while (offset + zone.ElementSize <= sizes.PAGE_SIZE) : (offset += zone.ElementSize) {
        const element: *FreeElement = @ptrCast(@alignCast(base + offset));
        element.Next = meta.FreeList;
        meta.FreeList = element;
    }
}

fn findPage(zone: *Zone, page_virtual: usize) ?*ZonePageMeta {
    var current = zone.PartialPages;
    while (current) |page_meta| {
        if (page_meta.PageVirtual == page_virtual) return page_meta;
        current = page_meta.Next;
    }
    current = zone.FullPages;
    while (current) |page_meta| {
        if (page_meta.PageVirtual == page_virtual) return page_meta;
        current = page_meta.Next;
    }
    return null;
}

fn removeFromFull(zone: *Zone, target: *ZonePageMeta) void {
    if (zone.FullPages == target) {
        zone.FullPages = target.Next;
        return;
    }
    var current = zone.FullPages;
    while (current) |page_meta| {
        if (page_meta.Next == target) {
            page_meta.Next = target.Next;
            return;
        }
        current = page_meta.Next;
    }
}
