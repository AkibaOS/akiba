//! Virtual Region Lifetime

const std = @import("std");

const common = @import("common");
const guard = @import("asm").interrupts.guard;
const labels = @import("mirai").memory.strings.range.messages;
const storage = @import("mirai").memory.range.storage;
const tree = @import("common").datatypes.tree;
const types = @import("mirai").memory.types.range;

const sizes = common.constants.memory.sizes;
const AllocationError = common.errors.memory.allocation.AllocationError;
const Region = types.region.Region;

pub fn initialize(region: *Region, base: u64, bytes: u64, name: []const u8) AllocationError!void {
    const flags = guard.acquire();
    defer guard.release(flags);
    if (region.Initialized or region.Location != 0 or region.Records.Count != 0 or region.Head != null or
        region.AddressIndex.Count != 0 or region.AddressIndex.Root != null or region.FreeSizes.Count != 0 or
        region.FreeSizes.Root != null or region.ReservedBytes != 0 or region.AllocatedCount != 0) return AllocationError.InvalidSize;
    if (bytes == 0 or (base & sizes.PAGE_MASK) != 0 or (bytes & sizes.PAGE_MASK) != 0 or
        bytes > std.math.maxInt(u64) - base) return AllocationError.InvalidSize;
    try region.Records.init(name);
    errdefer if (!region.Records.deinit()) @panic(labels.INVALID_STATE);
    const extent = try region.Records.reserve();
    extent.* = .{ .Owner = region, .Base = base, .Size = bytes, .Free = true };
    region.Base = base;
    region.End = base + bytes;
    region.Head = extent;
    region.Location = @intFromPtr(region);
    region.Initialized = true;
    storage.insert(region, extent);
}

pub fn deinitialize(region: *Region) bool {
    const flags = guard.acquire();
    defer guard.release(flags);
    if (!storage.valid(region) or region.ReservedBytes != 0 or region.AllocatedCount != 0 or
        region.Records.Count != 1 or region.AddressIndex.Count != 1 or region.FreeSizes.Count != 1) return false;
    const extent = region.Head orelse return false;
    if (!storage.owns(region, extent) or !extent.Free or extent.Before != null or extent.After != null or
        extent.Base != region.Base or extent.Size != region.End - region.Base or
        tree.lookup.find(&region.FreeSizes, storage.sizeKey(extent.Size, extent.Base)) != &extent.SizeIndex) return false;
    storage.remove(region, extent);
    storage.discard(region, extent);
    if (!region.Records.deinit()) @panic(labels.INVALID_STATE);
    region.Base = 0;
    region.End = 0;
    region.Head = null;
    region.Location = 0;
    region.Initialized = false;
    return true;
}
