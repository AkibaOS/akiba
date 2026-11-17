//! Virtual Extent Lookup

const fields = @import("mirai").memory.strings.range.fields;
const guard = @import("asm").interrupts.guard;
const storage = @import("mirai").memory.range.storage;
const tree = @import("common").datatypes.tree;
const types = @import("mirai").memory.types.range;

const Extent = types.extent.Extent;
const Region = types.region.Region;

pub fn find(region: *const Region, address: u64) ?*Extent {
    const flags = guard.acquire();
    defer guard.release(flags);
    if (!storage.valid(region)) return null;
    const node = tree.lookup.find(&region.AddressIndex, address) orelse return null;
    const extent: *Extent = @fieldParentPtr(fields.ADDRESS, node);
    return if (!extent.Free and storage.owns(region, extent)) extent else null;
}

pub fn contains(region: *const Region, address: u64) bool {
    const flags = guard.acquire();
    defer guard.release(flags);
    return storage.valid(region) and address >= region.Base and address < region.End;
}
