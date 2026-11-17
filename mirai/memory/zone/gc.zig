//! Zone Garbage Collection

const alloc = @import("mirai").memory.zone.alloc;
const bootstrap = @import("mirai").memory.zone.bootstrap;
const common = @import("common");
const guard = @import("asm").interrupts.guard;
const math = @import("utils").math;
const pages = @import("mirai").memory.zone.page;
const pmm = @import("mirai").pmm;
const tree = @import("common").datatypes.tree;
const types = @import("mirai").memory.types;

const sizes = common.constants.memory.sizes;
const Zone = types.zone.Zone;
const ZonePageMeta = types.zone.ZonePageMeta;

pub fn collect(zone: *Zone) usize {
    const previous_flags = guard.acquire();
    defer guard.release(previous_flags);
    const metadata = zone == bootstrap.getPageMetaZone();
    var freed: usize = 0;
    var current = zone.PartialPages;
    while (current) |meta| {
        const next = meta.Next;
        if (meta.InUse == 0 and !(metadata and bootstrap.isEarlyMeta(meta))) {
            releaseEmpty(zone, meta, metadata);
            freed += 1;
        }
        current = next;
    }
    return freed;
}

pub fn collectPage(zone: *Zone, pointer: *const anyopaque) usize {
    const previous_flags = guard.acquire();
    defer guard.release(previous_flags);
    const virtual = math.integer.alignDown(@intFromPtr(pointer), @as(usize, sizes.PAGE_SIZE));
    const meta = pages.find(zone, virtual) orelse return 0;
    const metadata = zone == bootstrap.getPageMetaZone();
    const early = bootstrap.isEarlyMeta(meta);
    if (meta.Zone != zone or meta.InUse != 0 or (metadata and early)) return 0;
    const record: *const anyopaque = @ptrCast(meta);
    releaseEmpty(zone, meta, metadata);
    const additional = if (!metadata and !early) collectPage(bootstrap.getPageMetaZone(), record) else 0;
    return 1 + additional;
}

fn releaseEmpty(zone: *Zone, meta: *ZonePageMeta, metadata: bool) void {
    pages.unlink(&zone.PartialPages, meta);
    if (!tree.remove.remove(&zone.PageIndex, &meta.Index)) unreachable;
    const physical = meta.PagePhysical;
    const early = bootstrap.isEarlyMeta(meta);
    zone.PageCount -= 1;
    pmm.free.single.freePage(physical);
    if (!metadata and !early) alloc.zfree(bootstrap.getPageMetaZone(), @ptrCast(meta));
}
