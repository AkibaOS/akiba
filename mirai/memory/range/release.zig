//! Allocation Free Virtual Extent Coalescing

const guard = @import("asm").interrupts.guard;
const storage = @import("mirai").memory.range.storage;
const types = @import("mirai").memory.types.range;

const Extent = types.extent.Extent;
const Region = types.region.Region;

pub fn release(region: *Region, extent: *Extent) bool {
    const flags = guard.acquire();
    defer guard.release(flags);
    if (!storage.owns(region, extent)) return false;
    if (extent.Free or extent.Size == 0 or extent.Base < region.Base or extent.Base > region.End or
        extent.Size > region.End - extent.Base or region.AllocatedCount == 0 or region.ReservedBytes < extent.Size) return false;
    if (extent.Before) |previous| {
        if (!storage.owns(region, previous) or previous.After != extent or previous.Base > extent.Base or
            previous.Size != extent.Base - previous.Base) return false;
    } else if (region.Head != extent or extent.Base != region.Base) return false;
    if (extent.After) |following| {
        if (!storage.owns(region, following) or following.Before != extent or
            following.Base != extent.Base + extent.Size) return false;
    } else if (extent.Base + extent.Size != region.End) return false;
    const released = extent.Size;
    storage.remove(region, extent);
    if (extent.Before) |previous| {
        if (previous.Free) {
            storage.remove(region, previous);
            extent.Base = previous.Base;
            extent.Size += previous.Size;
            extent.Before = previous.Before;
            storage.discard(region, previous);
        }
    }
    if (extent.After) |following| {
        if (following.Free) {
            storage.remove(region, following);
            extent.Size += following.Size;
            extent.After = following.After;
            storage.discard(region, following);
        }
    }
    if (extent.Before) |previous| previous.After = extent else region.Head = extent;
    if (extent.After) |following| following.Before = extent;
    extent.Free = true;
    storage.insert(region, extent);
    region.AllocatedCount -= 1;
    region.ReservedBytes -= released;
    return true;
}
