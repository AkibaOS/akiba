//! Zone Creation

const alloc = @import("mirai").memory.zone.alloc;
const bootstrap = @import("mirai").memory.zone.bootstrap;
const common = @import("common");
const constants = @import("mirai").memory.constants;
const guard = @import("asm").interrupts.guard;
const math = @import("utils").math;
const text = @import("utils").text;
const types = @import("mirai").memory.types;

const limits = constants.zone.limits;
const sizes = common.constants.memory.sizes;

const AllocationError = common.errors.memory.allocation.AllocationError;
const FreeElement = types.zone.FreeElement;
const Zone = types.zone.Zone;

pub fn create(name: []const u8, element_size: usize) AllocationError!*Zone {
    const previous_flags = guard.acquire();
    defer guard.release(previous_flags);

    if (!bootstrap.isInitialized()) return AllocationError.NotInitialized;

    const actual_size = @max(element_size, @sizeOf(FreeElement));
    if (actual_size > sizes.PAGE_SIZE) return AllocationError.SizeTooLarge;
    const aligned_size = math.integer.alignUp(actual_size, limits.ELEMENT_ALIGNMENT);

    const zone_zone = bootstrap.getZoneZone();
    const pointer = alloc.zalloc(zone_zone) catch return AllocationError.OutOfMemory;
    const zone: *Zone = @ptrCast(@alignCast(pointer));

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
