//! Bootstrap Zones

const types = @import("../../types/zone/zone.zig");
const Zone = types.Zone;
const ZonePageMeta = types.ZonePageMeta;
const FreeElement = types.FreeElement;
const page_size = types.page_size;
const min_elem_size = types.min_elem_size;

const convert = @import("../../convert/convert.zig");
const pmm = @import("../../../pmm/pmm.zig");

var zone_zone: Zone = undefined;
var page_meta_zone: Zone = undefined;

pub var early_page_metas: [4]ZonePageMeta = undefined;
var early_meta_used: usize = 0;

var initialized: bool = false;

pub fn init() !void {
    if (initialized) return;

    init_zone(&zone_zone, "zone_zone", @sizeOf(Zone));
    init_zone(&page_meta_zone, "page_meta_zone", @sizeOf(ZonePageMeta));

    try expand_zone_early(&zone_zone);
    try expand_zone_early(&page_meta_zone);

    initialized = true;
}

fn init_zone(zone: *Zone, name: []const u8, elem_size: usize) void {
    const actual_size = if (elem_size < min_elem_size) min_elem_size else elem_size;
    const aligned_size = (actual_size + 7) & ~@as(usize, 7);

    zone.elem_size = aligned_size;
    zone.elems_per_page = page_size / aligned_size;
    zone.partial_pages = null;
    zone.full_pages = null;
    zone.alloc_count = 0;
    zone.free_count = 0;
    zone.page_count = 0;

    const copy_len = @min(name.len, 31);
    @memcpy(zone.name[0..copy_len], name[0..copy_len]);
    zone.name_len = @truncate(copy_len);
}

fn expand_zone_early(zone: *Zone) !void {
    if (early_meta_used >= early_page_metas.len) return error.OutOfEarlyMeta;

    const phys = try pmm.allocate_page();
    const virt = convert.phys_to_virt(phys);

    const meta = &early_page_metas[early_meta_used];
    early_meta_used += 1;

    meta.zone = zone;
    meta.page_phys = phys;
    meta.page_virt = virt;
    meta.free_list = null;
    meta.in_use = 0;
    meta.next = zone.partial_pages;
    zone.partial_pages = meta;
    zone.page_count += 1;

    carve_page(zone, meta, virt);
}

fn carve_page(zone: *Zone, meta: *ZonePageMeta, page_virt: u64) void {
    const base: [*]u8 = @ptrFromInt(page_virt);
    var offset: usize = 0;

    while (offset + zone.elem_size <= page_size) : (offset += zone.elem_size) {
        const elem: *FreeElement = @ptrCast(@alignCast(base + offset));
        elem.next = meta.free_list;
        meta.free_list = elem;
    }
}

pub fn get_zone_zone() *Zone {
    return &zone_zone;
}

pub fn get_page_meta_zone() *Zone {
    return &page_meta_zone;
}

pub fn is_initialized() bool {
    return initialized;
}

pub fn is_early_meta(meta: *const ZonePageMeta) bool {
    const meta_addr = @intFromPtr(meta);
    const early_start = @intFromPtr(&early_page_metas);
    const early_end = early_start + @sizeOf(@TypeOf(early_page_metas));
    return meta_addr >= early_start and meta_addr < early_end;
}
