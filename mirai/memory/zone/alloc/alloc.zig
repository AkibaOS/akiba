//! Zone Allocation

const types = @import("../../types/zone/zone.zig");
const Zone = types.Zone;
const ZonePageMeta = types.ZonePageMeta;
const FreeElement = types.FreeElement;
const page_size = types.page_size;

const bootstrap = @import("../bootstrap/bootstrap.zig");
const convert = @import("../../convert/convert.zig");
const pmm = @import("../../../pmm/pmm.zig");

pub const AllocError = error{
    OutOfMemory,
};

pub fn zalloc(zone: *Zone) AllocError!*anyopaque {
    if (zone.partial_pages == null) {
        try expand(zone);
    }

    const page = zone.partial_pages orelse return AllocError.OutOfMemory;
    const elem = page.free_list orelse return AllocError.OutOfMemory;

    page.free_list = elem.next;
    page.in_use += 1;
    zone.alloc_count += 1;

    if (page.free_list == null) {
        zone.partial_pages = page.next;
        page.next = zone.full_pages;
        zone.full_pages = page;
    }

    return @ptrCast(elem);
}

pub fn zalloc_zeroed(zone: *Zone) AllocError!*anyopaque {
    const ptr = try zalloc(zone);
    const bytes: [*]u8 = @ptrCast(ptr);
    @memset(bytes[0..zone.elem_size], 0);
    return ptr;
}

pub fn zfree(zone: *Zone, ptr: *anyopaque) void {
    const page_virt = @intFromPtr(ptr) & ~@as(usize, page_size - 1);
    const page = find_page(zone, page_virt) orelse return;
    const was_full = (page.free_list == null);

    const elem: *FreeElement = @ptrCast(@alignCast(ptr));
    elem.next = page.free_list;
    page.free_list = elem;
    page.in_use -|= 1;
    zone.free_count += 1;

    if (was_full) {
        remove_from_full(zone, page);
        page.next = zone.partial_pages;
        zone.partial_pages = page;
    }
}

fn expand(zone: *Zone) AllocError!void {
    const phys = pmm.allocate_page() catch return AllocError.OutOfMemory;
    const virt = convert.phys_to_virt(phys);

    const page_meta_zone = bootstrap.get_page_meta_zone();
    const meta_ptr = zalloc(page_meta_zone) catch {
        pmm.free_page(phys);
        return AllocError.OutOfMemory;
    };
    const meta: *ZonePageMeta = @ptrCast(@alignCast(meta_ptr));

    meta.zone = zone;
    meta.page_phys = phys;
    meta.page_virt = virt;
    meta.free_list = null;
    meta.in_use = 0;
    meta.next = zone.partial_pages;
    zone.partial_pages = meta;
    zone.page_count += 1;

    const base: [*]u8 = @ptrFromInt(virt);
    var offset: usize = 0;
    while (offset + zone.elem_size <= page_size) : (offset += zone.elem_size) {
        const elem: *FreeElement = @ptrCast(@alignCast(base + offset));
        elem.next = meta.free_list;
        meta.free_list = elem;
    }
}

fn find_page(zone: *Zone, page_virt: usize) ?*ZonePageMeta {
    var current = zone.partial_pages;
    while (current) |page_meta| {
        if (page_meta.page_virt == page_virt) return page_meta;
        current = page_meta.next;
    }
    current = zone.full_pages;
    while (current) |page_meta| {
        if (page_meta.page_virt == page_virt) return page_meta;
        current = page_meta.next;
    }
    return null;
}

fn remove_from_full(zone: *Zone, target: *ZonePageMeta) void {
    if (zone.full_pages == target) {
        zone.full_pages = target.next;
        return;
    }
    var current = zone.full_pages;
    while (current) |page_meta| {
        if (page_meta.next == target) {
            page_meta.next = target.next;
            return;
        }
        current = page_meta.next;
    }
}
