//! Virtual Extent Index And Metadata Ownership

const labels = @import("mirai").memory.strings.range.messages;
const tree = @import("common").datatypes.tree;
const types = @import("mirai").memory.types.range;

const Extent = types.extent.Extent;
const Region = types.region.Region;

pub fn valid(region: *const Region) bool {
    return region.Initialized and region.Location == @intFromPtr(region) and region.Records.Zone != null and
        region.Records.Location == @intFromPtr(&region.Records);
}

pub fn owns(region: *const Region, extent: *const Extent) bool {
    if (!valid(region) or !region.Records.owns(extent)) return false;
    return extent.Owner == region and tree.lookup.find(&region.AddressIndex, extent.Base) == &extent.AddressIndex;
}

pub fn sizeKey(size: u64, base: u64) u128 {
    return (@as(u128, size) << @bitSizeOf(u64)) | base;
}

pub fn insert(region: *Region, extent: *Extent) void {
    if (!tree.insert.insert(&region.AddressIndex, &extent.AddressIndex, extent.Base)) @panic(labels.INVALID_STATE);
    if (extent.Free and !tree.insert.insert(&region.FreeSizes, &extent.SizeIndex, sizeKey(extent.Size, extent.Base)))
        @panic(labels.INVALID_STATE);
}

pub fn remove(region: *Region, extent: *Extent) void {
    if (!tree.remove.remove(&region.AddressIndex, &extent.AddressIndex)) @panic(labels.INVALID_STATE);
    if (extent.Free and !tree.remove.remove(&region.FreeSizes, &extent.SizeIndex)) @panic(labels.INVALID_STATE);
}

pub fn discard(region: *Region, extent: *Extent) void {
    if (!region.Records.release(extent)) @panic(labels.INVALID_STATE);
    _ = region.Records.collectAt(extent);
}
