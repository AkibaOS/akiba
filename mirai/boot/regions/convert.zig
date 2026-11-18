//! Consuming UEFI Memory Map Canonicalization

const std = @import("std");

const boot = @import("shared").boot;
const common = @import("common");
const pmm = @import("mirai").pmm;

const layout = common.constants.memory.layout;
const memory = boot.constants.memory;
const sizes = common.constants.memory.sizes;
const Descriptor = boot.types.memory.UefiMemoryDescriptor;
const MemoryRegion = pmm.types.region.MemoryRegion;
const RegionType = pmm.types.region.RegionType;

pub fn consume(map: boot.types.memory.MemoryMapInfo, physical_limit: u64) ?[]const MemoryRegion {
    if (physical_limit == 0 or physical_limit > layout.PHYSMAP_MAX_SIZE or map.Entries == 0 or map.EntryCount == 0 or
        map.EntrySize < @sizeOf(Descriptor) or map.EntrySize < @sizeOf(MemoryRegion) or
        map.EntrySize % @alignOf(Descriptor) != 0 or map.Entries % @alignOf(Descriptor) != 0 or
        map.Entries % @alignOf(MemoryRegion) != 0 or map.DescriptorVersion != memory.DESCRIPTOR_VERSION) return null;
    const bytes = @as(u64, map.EntryCount) * map.EntrySize;
    if (map.Entries >= physical_limit or bytes > physical_limit - map.Entries) return null;
    const base = layout.PHYSMAP_BASE + map.Entries;
    for (0..map.EntryCount) |index| {
        const descriptor: *const Descriptor = @ptrFromInt(base + index * map.EntrySize);
        if ((descriptor.PhysicalStart & sizes.PAGE_MASK) != 0 or descriptor.NumberOfPages == 0 or
            descriptor.NumberOfPages > (std.math.maxInt(u64) - descriptor.PhysicalStart) / sizes.PAGE_SIZE) return null;
    }
    const storage: [*]MemoryRegion = @ptrFromInt(base);
    for (0..map.EntryCount) |index| {
        const pointer: *const Descriptor = @ptrFromInt(base + index * map.EntrySize);
        const descriptor = pointer.*;
        storage[index] = .{
            .BaseAddress = descriptor.PhysicalStart,
            .Length = descriptor.NumberOfPages * sizes.PAGE_SIZE,
            .RegionType = classify(descriptor.MemoryType),
        };
    }
    const regions = storage[0..map.EntryCount];
    std.mem.sort(MemoryRegion, regions, {}, earlier);
    for (regions[1..], regions[0 .. regions.len - 1]) |region, previous| {
        if (region.BaseAddress < previous.BaseAddress + previous.Length) return null;
    }
    return regions;
}

fn earlier(_: void, left: MemoryRegion, right: MemoryRegion) bool {
    return left.BaseAddress < right.BaseAddress;
}

fn classify(memory_type: boot.types.memory.UefiMemoryType) RegionType {
    return switch (memory_type) {
        .Conventional => .Available,
        .ACPIReclaim => .ACPIReclaimable,
        .ACPINVS => .ACPINVS,
        .Unusable => .Bad,
        else => .Reserved,
    };
}
