//! Transactional Virtual Extent Reservation

const std = @import("std");

const common = @import("common");
const fields = @import("mirai").memory.strings.range.fields;
const guard = @import("asm").interrupts.guard;
const storage = @import("mirai").memory.range.storage;
const tree = @import("common").datatypes.tree;
const types = @import("mirai").memory.types.range;

const sizes = common.constants.memory.sizes;
const AllocationError = common.errors.memory.allocation.AllocationError;
const Extent = types.extent.Extent;
const Region = types.region.Region;

pub fn reserve(region: *Region, bytes: u64, alignment: u64) AllocationError!*Extent {
    const flags = guard.acquire();
    defer guard.release(flags);
    if (!storage.valid(region)) return AllocationError.InvalidSize;
    if (bytes == 0 or (bytes & sizes.PAGE_MASK) != 0) return AllocationError.InvalidSize;
    if (alignment < sizes.PAGE_SIZE or (alignment & (alignment - 1)) != 0) return AllocationError.InvalidAlignment;
    if (region.AllocatedCount == std.math.maxInt(usize) or bytes > std.math.maxInt(u64) - region.ReservedBytes)
        return AllocationError.RegionExhausted;
    var current = tree.lookup.lowerBound(&region.FreeSizes, storage.sizeKey(bytes, 0));
    while (current) |node| : (current = tree.lookup.next(node)) {
        const extent: *Extent = @fieldParentPtr(fields.SIZE, node);
        const mask = alignment - 1;
        if (extent.Base > std.math.maxInt(u64) - mask) continue;
        const aligned = (extent.Base + mask) & ~mask;
        const padding = aligned - extent.Base;
        if (padding > extent.Size or bytes > extent.Size - padding) continue;
        return split(region, extent, aligned, bytes);
    }
    return AllocationError.RegionExhausted;
}

fn split(region: *Region, extent: *Extent, base: u64, bytes: u64) AllocationError!*Extent {
    const padding = base - extent.Base;
    const remaining = extent.Size - padding - bytes;
    var prefix: ?*Extent = null;
    var suffix: ?*Extent = null;
    errdefer {
        if (prefix) |record| storage.discard(region, record);
        if (suffix) |record| storage.discard(region, record);
    }
    if (padding != 0) {
        prefix = try region.Records.reserve();
        prefix.?.* = .{ .Owner = region, .Base = extent.Base, .Size = padding, .Free = true };
    }
    if (remaining != 0) {
        suffix = try region.Records.reserve();
        suffix.?.* = .{ .Owner = region, .Base = base + bytes, .Size = remaining, .Free = true };
    }
    const previous = extent.Before;
    const following = extent.After;
    storage.remove(region, extent);
    extent.Base = base;
    extent.Size = bytes;
    extent.Free = false;
    extent.Before = prefix orelse previous;
    extent.After = suffix orelse following;
    if (prefix) |record| {
        record.Before = previous;
        record.After = extent;
        storage.insert(region, record);
    }
    if (suffix) |record| {
        record.Before = extent;
        record.After = following;
        storage.insert(region, record);
    }
    const first = prefix orelse extent;
    const last = suffix orelse extent;
    if (previous) |record| record.After = first else region.Head = first;
    if (following) |record| record.Before = last;
    storage.insert(region, extent);
    region.AllocatedCount += 1;
    region.ReservedBytes += bytes;
    return extent;
}
