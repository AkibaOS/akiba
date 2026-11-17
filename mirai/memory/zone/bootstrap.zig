//! Bootstrap Zones

const common = @import("common");
const constants = @import("mirai").memory.constants;
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

pub var early_page_metas: [limits.EARLY_META_COUNT]ZonePageMeta = undefined;
var early_meta_used: usize = 0;

var initialized: bool = false;

pub fn init() AllocationError!void {
    if (initialized) return;

    initZone(&zone_zone, labels.ZONE, @sizeOf(Zone));
    initZone(&page_meta_zone, labels.PAGE_METADATA, @sizeOf(ZonePageMeta));

    try expandZoneEarly(&zone_zone);
    try expandZoneEarly(&page_meta_zone);

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

fn expandZoneEarly(zone: *Zone) AllocationError!void {
    if (early_meta_used >= early_page_metas.len) return AllocationError.OutOfMemory;

    const physical = try pmm.allocate.single.allocatePage();
    const meta = &early_page_metas[early_meta_used];
    early_meta_used += 1;
    page.attach(zone, meta, physical, 0);
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
