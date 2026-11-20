//! Checked UEFI Map Read View And Consuming Canonicalization

const std = @import("std");

const boot = @import("shared").boot;
const common = @import("common");
const pmm = @import("mirai").pmm;
const retirement = @import("mirai").boot.types.retirement.footprint;

const layout = common.constants.memory.layout;
const memory = boot.constants.memory;
const sizes = common.constants.memory.sizes;
const Descriptor = boot.types.memory.UefiMemoryDescriptor;
const MemoryRegion = pmm.types.region.MemoryRegion;
const RawMap = retirement.RawMap;
const RegionType = pmm.types.region.RegionType;
const Range = pmm.types.storage.layout.Range;

pub fn inspect(map: boot.types.memory.MemoryMapInfo, physical_limit: u64) ?RawMap {
    if (physical_limit == 0 or physical_limit > layout.PHYSMAP_MAX_SIZE or map.Entries == 0 or map.EntryCount == 0 or
        map.EntrySize < @sizeOf(Descriptor) or map.EntrySize < @sizeOf(MemoryRegion) or
        map.EntrySize % @alignOf(Descriptor) != 0 or map.Entries % @alignOf(Descriptor) != 0 or
        map.Entries % @alignOf(MemoryRegion) != 0 or map.DescriptorVersion != memory.DESCRIPTOR_VERSION) return null;
    const bytes = @as(u64, map.EntryCount) * map.EntrySize;
    if (map.Entries >= physical_limit or bytes > physical_limit - map.Entries) return null;
    var ordered = true;
    var previous_end: u64 = 0;
    for (0..map.EntryCount) |index| {
        const descriptor = read(map, index);
        if ((descriptor.PhysicalStart & sizes.PAGE_MASK) != 0 or descriptor.NumberOfPages == 0 or
            descriptor.NumberOfPages > (std.math.maxInt(u64) - descriptor.PhysicalStart) / sizes.PAGE_SIZE) return null;
        if (descriptor.PhysicalStart < previous_end) ordered = false;
        previous_end = descriptorEnd(descriptor);
    }
    return .{ .Map = map, .Ordered = ordered };
}

pub fn ownsLoaderBacking(view: RawMap, range: Range) bool {
    var start = range.Start * sizes.PAGE_SIZE;
    const end = range.End * sizes.PAGE_SIZE;
    if (view.Ordered) {
        var index = lowerEnd(view.Map, start);
        while (start < end and index < view.Map.EntryCount) : (index += 1) {
            const descriptor = read(view.Map, index);
            if (descriptor.PhysicalStart > start or classify(descriptor.MemoryType, descriptor.Attribute) != .LoaderData) return false;
            start = descriptorEnd(descriptor);
        }
        return start >= end;
    }
    while (start < end) {
        var owner: ?usize = null;
        var next = start;
        for (0..view.Map.EntryCount) |index| {
            const descriptor = read(view.Map, index);
            if (descriptor.PhysicalStart > start or descriptorEnd(descriptor) <= start) continue;
            if (owner != null or classify(descriptor.MemoryType, descriptor.Attribute) != .LoaderData) return false;
            owner = index;
            next = @min(end, descriptorEnd(descriptor));
        }
        const selected = owner orelse return false;
        for (0..view.Map.EntryCount) |index| {
            if (index == selected) continue;
            const descriptor = read(view.Map, index);
            if (descriptor.PhysicalStart < next and descriptorEnd(descriptor) > start) return false;
        }
        start = next;
    }
    return true;
}

pub fn consume(map: boot.types.memory.MemoryMapInfo, physical_limit: u64) ?[]const MemoryRegion {
    _ = inspect(map, physical_limit) orelse return null;
    const storage: [*]MemoryRegion = @ptrFromInt(layout.PHYSMAP_BASE + map.Entries);
    for (0..map.EntryCount) |index| {
        const descriptor = read(map, index);
        storage[index] = .{
            .BaseAddress = descriptor.PhysicalStart,
            .Length = descriptor.NumberOfPages * sizes.PAGE_SIZE,
            .RegionType = classify(descriptor.MemoryType, descriptor.Attribute),
        };
    }
    const regions = storage[0..map.EntryCount];
    std.mem.sort(MemoryRegion, regions, {}, earlier);
    for (regions[1..], regions[0 .. regions.len - 1]) |region, previous| {
        if (region.BaseAddress < previous.endAddress()) return null;
    }
    return regions;
}

fn read(map: boot.types.memory.MemoryMapInfo, index: usize) Descriptor {
    const pointer: *const Descriptor = @ptrFromInt(layout.PHYSMAP_BASE + map.Entries + index * map.EntrySize);
    return pointer.*;
}

fn descriptorEnd(descriptor: Descriptor) u64 {
    return descriptor.PhysicalStart + descriptor.NumberOfPages * sizes.PAGE_SIZE;
}

fn lowerEnd(map: boot.types.memory.MemoryMapInfo, physical: u64) usize {
    var low: usize = 0;
    var high: usize = map.EntryCount;
    while (low < high) {
        const middle = low + (high - low) / 2;
        if (descriptorEnd(read(map, middle)) <= physical) low = middle + 1 else high = middle;
    }
    return low;
}

fn earlier(_: void, left: MemoryRegion, right: MemoryRegion) bool {
    return left.BaseAddress < right.BaseAddress;
}

fn classify(memory_type: boot.types.memory.UefiMemoryType, attributes: u64) RegionType {
    if (attributes & memory.RUNTIME_ATTRIBUTE != 0) return .Reserved;
    return switch (memory_type) {
        .Conventional => .Available,
        .LoaderData => if (attributes & memory.LOADER_RETIREMENT_FORBIDDEN == 0) .LoaderData else .Reserved,
        .ACPIReclaim => .ACPIReclaimable,
        .ACPINVS => .ACPINVS,
        .Unusable => .Bad,
        else => .Reserved,
    };
}
