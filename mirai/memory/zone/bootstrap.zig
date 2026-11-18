//! Bootstrap Zones

const common = @import("common");
const constants = @import("mirai").memory.constants;
const guard = @import("asm").interrupts.guard;
const math = @import("utils").math;
const page = @import("mirai").memory.zone.page;
const pmm = @import("mirai").pmm;
const strings = @import("mirai").memory.strings;
const text = @import("utils").text;
const types = @import("mirai").memory.types;

const labels = strings.zone.labels;
const limits = constants.zone.limits;
const sizes = common.constants.memory.sizes;

const AllocationError = common.errors.memory.allocation.AllocationError;
const FreeElement = types.zone.FreeElement;
const Zone = types.zone.Zone;
const ZonePageMeta = types.zone.ZonePageMeta;

var zone_zone: Zone = undefined;
var page_meta_zone: Zone = undefined;

var zone_seed: ZonePageMeta = undefined;
var metadata_seed: ZonePageMeta = undefined;

var initialized: bool = false;

pub fn init() AllocationError!void {
    const previous_flags = guard.acquire();
    defer guard.release(previous_flags);
    if (initialized) return;

    const search_start = pmm.state.getState().SearchStart;
    errdefer pmm.state.getState().SearchStart = search_start;
    const zone_physical = try pmm.allocate.single.allocatePage();
    errdefer pmm.free.single.freePage(zone_physical);
    const metadata_physical = try pmm.allocate.single.allocatePage();

    initZone(&zone_zone, labels.ZONE, @sizeOf(Zone));
    initZone(&page_meta_zone, labels.PAGE_METADATA, @sizeOf(ZonePageMeta));
    page.attach(&zone_zone, &zone_seed, zone_physical, 0);
    page.attach(&page_meta_zone, &metadata_seed, metadata_physical, 0);
    initialized = true;
}

fn initZone(zone: *Zone, name: []const u8, element_size: usize) void {
    const actual_size = @max(element_size, @sizeOf(FreeElement));
    const aligned_size = math.integer.alignUp(actual_size, limits.ELEMENT_ALIGNMENT);

    zone.ElementSize = aligned_size;
    zone.ElementsPerPage = sizes.PAGE_SIZE / aligned_size;
    zone.PartialPages = null;
    zone.FullPages = null;
    zone.AllocationCount = 0;
    zone.FreeCount = 0;
    zone.PageCount = 0;
    zone.PageIndex = .{};

    const copy_length = text.ascii.copyBounded(zone.Name[0 .. limits.NAME_CAPACITY - 1], name);
    zone.NameLength = @truncate(copy_length);
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
    return meta == &zone_seed or meta == &metadata_seed;
}
