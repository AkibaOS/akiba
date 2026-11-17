//! Zone Garbage Collection

const alloc = @import("mirai").memory.zone.alloc;
const bootstrap = @import("mirai").memory.zone.bootstrap;
const guard = @import("asm").interrupts.guard;
const pmm = @import("mirai").pmm;
const tree = @import("common").datatypes.tree;
const types = @import("mirai").memory.types;

const Zone = types.zone.Zone;
const ZonePageMeta = types.zone.ZonePageMeta;

pub fn collect(zone: *Zone) usize {
    const previous_flags = guard.acquire();
    defer guard.release(previous_flags);

    const metadata = zone == bootstrap.getPageMetaZone();

    var freed: usize = 0;
    var previous: ?*ZonePageMeta = null;
    var current = zone.PartialPages;

    while (current) |page_meta| {
        const next_page = page_meta.Next;

        if (page_meta.InUse == 0 and !(metadata and bootstrap.isEarlyMeta(page_meta))) {
            if (!tree.remove.remove(&zone.PageIndex, &page_meta.Index)) unreachable;
            if (previous) |previous_page| {
                previous_page.Next = next_page;
            } else {
                zone.PartialPages = next_page;
            }

            const physical = page_meta.PagePhysical;
            const early = bootstrap.isEarlyMeta(page_meta);
            zone.PageCount -= 1;
            pmm.free.single.freePage(physical);

            if (!metadata and !early) {
                alloc.zfree(bootstrap.getPageMetaZone(), @ptrCast(page_meta));
            }

            freed += 1;
        } else {
            previous = page_meta;
        }

        current = next_page;
    }

    return freed;
}
