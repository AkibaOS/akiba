//! Bootstrap Zones

const common = @import("common");

const constants = @import("../constants/constants.zig");
const convert = @import("../convert/convert.zig");
const pmm = @import("../../pmm/pmm.zig");
const types = @import("../types/types.zig");

const limits = constants.zone.limits;
const sizes = common.constants.memory.sizes;

const AllocationError = common.errors.memory.allocation.AllocationError;
const FreeElement = types.zone.FreeElement;
const Zone = types.zone.Zone;
const ZonePageMeta = types.zone.ZonePageMeta;

var zone_zone: Zone = undefined;
var page_meta_zone: Zone = undefined;

pub var early_page_metas: [limits.EARLY_META_COUNT]ZonePageMeta = undefined;
var early_meta_used: usize = 0;

var initialized: bool = false;

pub fn init() AllocationError!void {
    if (initialized) return;

    initZone(&zone_zone, "zone_zone", @sizeOf(Zone));
    initZone(&page_meta_zone, "page_meta_zone", @sizeOf(ZonePageMeta));

    try expandZoneEarly(&zone_zone);
    try expandZoneEarly(&page_meta_zone);

    initialized = true;
}

fn initZone(zone: *Zone, name: []const u8, element_size: usize) void {
    const actual_size = @max(element_size, @sizeOf(FreeElement));
    const aligned_size = (actual_size + limits.ELEMENT_ALIGNMENT - 1) & ~(limits.ELEMENT_ALIGNMENT - 1);

    zone.ElementSize = aligned_size;
    zone.ElementsPerPage = sizes.PAGE_SIZE / aligned_size;
    zone.PartialPages = null;
    zone.FullPages = null;
    zone.AllocationCount = 0;
    zone.FreeCount = 0;
    zone.PageCount = 0;

    const copy_length = @min(name.len, limits.NAME_CAPACITY - 1);
    @memcpy(zone.Name[0..copy_length], name[0..copy_length]);
    zone.NameLength = @truncate(copy_length);
}

fn expandZoneEarly(zone: *Zone) AllocationError!void {
    if (early_meta_used >= early_page_metas.len) return AllocationError.OutOfMemory;

    const physical = try pmm.allocate.single.allocatePage();
    const virtual = convert.physToVirt(physical);

    const meta = &early_page_metas[early_meta_used];
    early_meta_used += 1;

    meta.Zone = zone;
    meta.PagePhysical = physical;
    meta.PageVirtual = virtual;
    meta.FreeList = null;
    meta.InUse = 0;
    meta.Next = zone.PartialPages;
    zone.PartialPages = meta;
    zone.PageCount += 1;

    carvePage(zone, meta, virtual);
}

fn carvePage(zone: *Zone, meta: *ZonePageMeta, page_virtual: u64) void {
    const base: [*]u8 = @ptrFromInt(page_virtual);
    var offset: usize = 0;

    while (offset + zone.ElementSize <= sizes.PAGE_SIZE) : (offset += zone.ElementSize) {
        const element: *FreeElement = @ptrCast(@alignCast(base + offset));
        element.Next = meta.FreeList;
        meta.FreeList = element;
    }
}

pub fn getZoneZone() *Zone {
    return &zone_zone;
}

pub fn getPageMetaZone() *Zone {
    return &page_meta_zone;
}

pub fn isInitialized() bool {
    return initialized;
}

pub fn isEarlyMeta(meta: *const ZonePageMeta) bool {
    const meta_address = @intFromPtr(meta);
    const early_start = @intFromPtr(&early_page_metas);
    const early_end = early_start + @sizeOf(@TypeOf(early_page_metas));
    return meta_address >= early_start and meta_address < early_end;
}
