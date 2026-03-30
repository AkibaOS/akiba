//! Zone Garbage Collection

const types = @import("../types/types.zig");
const Zone = types.Zone;
const ZonePageMeta = types.ZonePageMeta;

const bootstrap = @import("../bootstrap/bootstrap.zig");
const alloc_mod = @import("../alloc/alloc.zig");
const pmm = @import("../../../pmm/pmm.zig");

pub fn collect(zone: *Zone) usize {
    var freed: usize = 0;
    var prev: ?*ZonePageMeta = null;
    var current = zone.partial_pages;

    while (current) |page_meta| {
        const next_page = page_meta.next;

        if (page_meta.in_use == 0) {
            if (prev) |prev_page| {
                prev_page.next = next_page;
            } else {
                zone.partial_pages = next_page;
            }

            zone.page_count -|= 1;
            pmm.free_page(page_meta.page_phys);

            if (!bootstrap.is_early_meta(page_meta)) {
                const page_meta_zone = bootstrap.get_page_meta_zone();
                alloc_mod.zfree(page_meta_zone, @ptrCast(page_meta));
            }

            freed += 1;
        } else {
            prev = page_meta;
        }

        current = next_page;
    }

    return freed;
}
