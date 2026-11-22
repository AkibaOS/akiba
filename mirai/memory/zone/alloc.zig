//! Zone Allocation

const address = @import("common").memory;
const bits = @import("common").bitmap;
const bootstrap = @import("mirai").memory.zone.bootstrap;
const common = @import("common");
const guard = @import("asm").interrupts.guard;
const limits = @import("mirai").memory.constants.zone.limits;
const math = @import("common").math;
const pages = @import("mirai").memory.zone.page;
const pmm = @import("mirai").pmm;
const types = @import("mirai").memory.types;

const sizes = common.constants.memory.sizes;

const AllocationError = common.errors.memory.allocation.AllocationError;
const FreeElement = types.zone.layout.FreeElement;
const Zone = types.zone.layout.Zone;
const ZonePageMeta = types.zone.layout.ZonePageMeta;

pub fn zalloc(zone: *Zone) AllocationError!*anyopaque {
    const previous_flags = guard.acquire();
    defer guard.release(previous_flags);

    if (zone.PartialPages == null) {
        try expand(zone);
    }

    const page = zone.PartialPages orelse return AllocationError.OutOfMemory;
    const element = page.FreeList orelse return AllocationError.OutOfMemory;
    const index = elementIndex(zone, page, @intFromPtr(element)) orelse return AllocationError.ZoneExhausted;
    if (page.InUse >= page.Capacity or bits.operations.testBit(&page.Allocated, index)) return AllocationError.ZoneExhausted;

    page.FreeList = element.Next;
    bits.operations.setBit(&page.Allocated, index);
    page.InUse += 1;
    zone.AllocationCount += 1;

    if (page.FreeList == null) {
        pages.unlink(&zone.PartialPages, page);
        pages.prepend(&zone.FullPages, page);
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
    const previous_flags = guard.acquire();
    defer guard.release(previous_flags);

    const page_virtual = math.integer.alignDown(@intFromPtr(pointer), @as(usize, sizes.PAGE_SIZE));
    const page = pages.find(zone, page_virtual) orelse return;
    const index = elementIndex(zone, page, @intFromPtr(pointer)) orelse return;
    if (!bits.operations.testBit(&page.Allocated, index)) return;
    const was_full = (page.FreeList == null);

    const element: *FreeElement = @ptrCast(@alignCast(pointer));
    element.Next = page.FreeList;
    page.FreeList = element;
    bits.operations.clearBit(&page.Allocated, index);
    page.InUse -= 1;
    zone.FreeCount += 1;

    if (was_full) {
        pages.unlink(&zone.FullPages, page);
        pages.prepend(&zone.PartialPages, page);
    }
}

fn expand(zone: *Zone) AllocationError!void {
    const page_meta_zone = bootstrap.getPageMetaZone();
    const physical = try pmm.allocate.single.allocatePage();
    errdefer pmm.free.single.freePage(physical);
    const virtual = address.translate.physToVirt(physical);
    const self_hosted = zone == page_meta_zone;
    const meta: *ZonePageMeta = if (self_hosted)
        @ptrFromInt(virtual)
    else
        @ptrCast(@alignCast(try zalloc(page_meta_zone)));
    const offset = if (self_hosted)
        math.integer.alignUp(@as(usize, @sizeOf(ZonePageMeta)), limits.ELEMENT_ALIGNMENT)
    else
        0;
    pages.attach(zone, meta, physical, offset);
}

pub fn owns(zone: *const Zone, pointer: *const anyopaque) bool {
    const previous_flags = guard.acquire();
    defer guard.release(previous_flags);
    const page_virtual = math.integer.alignDown(@intFromPtr(pointer), @as(usize, sizes.PAGE_SIZE));
    const page = pages.find(zone, page_virtual) orelse return false;
    const index = elementIndex(zone, page, @intFromPtr(pointer)) orelse return false;
    return bits.operations.testBit(&page.Allocated, index);
}

fn elementIndex(zone: *const Zone, meta: *const ZonePageMeta, pointer: usize) ?usize {
    if (meta.Zone != zone or zone.ElementSize == 0 or pointer < meta.PageVirtual) return null;
    const offset = pointer - meta.PageVirtual;
    if (offset < meta.ElementOffset) return null;
    const payload_offset = offset - meta.ElementOffset;
    if (payload_offset % zone.ElementSize != 0) return null;
    const index = payload_offset / zone.ElementSize;
    return if (index < meta.Capacity) index else null;
}
