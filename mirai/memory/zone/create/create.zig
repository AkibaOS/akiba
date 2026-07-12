//! Zone Creation

const types = @import("../../types/zone/zone.zig");
const Zone = types.Zone;
const page_size = types.page_size;
const min_elem_size = types.min_elem_size;

const bootstrap = @import("../bootstrap/bootstrap.zig");
const alloc_mod = @import("../alloc/alloc.zig");

pub const CreateError = error{
    NotInitialized,
    OutOfMemory,
};

pub fn create(name: []const u8, elem_size: usize) CreateError!*Zone {
    if (!bootstrap.is_initialized()) return CreateError.NotInitialized;

    const zone_zone = bootstrap.get_zone_zone();
    const ptr = alloc_mod.zalloc(zone_zone) catch return CreateError.OutOfMemory;
    const zone: *Zone = @ptrCast(@alignCast(ptr));

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

    return zone;
}
