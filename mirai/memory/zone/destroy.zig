//! Dynamic Zone Destruction

const alloc = @import("mirai").memory.zone.alloc;
const bootstrap = @import("mirai").memory.zone.bootstrap;
const gc = @import("mirai").memory.zone.gc;
const guard = @import("asm").interrupts.guard;
const types = @import("mirai").memory.types;

const Zone = types.zone.Zone;

pub fn destroy(zone: *Zone) bool {
    const flags = guard.acquire();
    defer guard.release(flags);
    const zones = bootstrap.getZoneZone();
    if (zone == zones or zone == bootstrap.getPageMetaZone() or !alloc.owns(zones, @ptrCast(zone))) return false;
    if (zone.inUse() != 0) return false;
    _ = gc.collect(zone);
    if (zone.PageCount != 0 or zone.PageIndex.Count != 0 or zone.PageIndex.Root != null) return false;
    alloc.zfree(zones, @ptrCast(zone));
    return true;
}
