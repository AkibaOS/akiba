//! Zone Creation

const common = @import("common");

const alloc = @import("mirai").memory.zone.alloc;
const bootstrap = @import("mirai").memory.zone.bootstrap;
const constants = @import("mirai").memory.constants;
const types = @import("mirai").memory.types;

const math = @import("utils").math;
const text = @import("utils").text;

const limits = constants.zone.limits;
const sizes = common.constants.memory.sizes;

const AllocationError = common.errors.memory.allocation.AllocationError;
const FreeElement = types.zone.FreeElement;
const Zone = types.zone.Zone;

pub fn create(name: []const u8, element_size: usize) AllocationError!*Zone {
    if (!bootstrap.isInitialized()) return AllocationError.NotInitialized;

    const zone_zone = bootstrap.getZoneZone();
    const pointer = alloc.zalloc(zone_zone) catch return AllocationError.OutOfMemory;
    const zone: *Zone = @ptrCast(@alignCast(pointer));

    const actual_size = @max(element_size, @sizeOf(FreeElement));
    const aligned_size = math.integer.alignUp(actual_size, limits.ELEMENT_ALIGNMENT);

    zone.ElementSize = aligned_size;
    zone.ElementsPerPage = sizes.PAGE_SIZE / aligned_size;
    zone.PartialPages = null;
    zone.FullPages = null;
    zone.AllocationCount = 0;
    zone.FreeCount = 0;
    zone.PageCount = 0;

    const copy_length = text.ascii.copyBounded(zone.Name[0 .. limits.NAME_CAPACITY - 1], name);
    zone.NameLength = @truncate(copy_length);

    return zone;
}
