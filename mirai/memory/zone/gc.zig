//! Zone Garbage Collection

const alloc = @import("mirai").memory.zone.alloc;
const bootstrap = @import("mirai").memory.zone.bootstrap;
const pmm = @import("mirai").pmm;
const types = @import("mirai").memory.types;

const Zone = types.zone.Zone;
const ZonePageMeta = types.zone.ZonePageMeta;

pub fn collect(zone: *Zone) usize {
    var freed: usize = 0;
    var previous: ?*ZonePageMeta = null;
    var current = zone.PartialPages;

    while (current) |page_meta| {
        const next_page = page_meta.Next;

        if (page_meta.InUse == 0) {
            if (previous) |previous_page| {
                previous_page.Next = next_page;
            } else {
                zone.PartialPages = next_page;
            }

            zone.PageCount -|= 1;
            pmm.free.single.freePage(page_meta.PagePhysical);

            if (!bootstrap.isEarlyMeta(page_meta)) {
                const page_meta_zone = bootstrap.getPageMetaZone();
                alloc.zfree(page_meta_zone, @ptrCast(page_meta));
            }

            freed += 1;
        } else {
            previous = page_meta;
        }

        current = next_page;
    }

    return freed;
}
