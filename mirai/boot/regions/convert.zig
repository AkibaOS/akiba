//! UEFI Memory Map Conversion

const std = @import("std");

const boot = @import("shared").boot;
const common = @import("common");
const constants = @import("mirai").boot.constants;
const pmm = @import("mirai").pmm;
const state = @import("mirai").boot.regions.state;

const limits = constants.regions.limits;
const layout = common.constants.memory.layout;
const memory = boot.constants.memory;
const sizes = common.constants.memory.sizes;
const MemoryRegion = pmm.types.region.MemoryRegion;
const RegionType = pmm.types.region.RegionType;

pub fn convert(map: boot.types.memory.MemoryMapInfo, physical_limit: u64) ?[]const MemoryRegion {
    if (physical_limit == 0 or physical_limit > layout.PHYSMAP_MAX_SIZE or map.Entries == 0 or
        map.EntryCount == 0 or map.EntryCount > limits.MAX_REGIONS or
        map.EntrySize < @sizeOf(boot.types.memory.UefiMemoryDescriptor) or map.EntrySize > memory.MAX_DESCRIPTOR_SIZE or
        map.EntrySize % @alignOf(boot.types.memory.UefiMemoryDescriptor) != 0 or
        map.Entries % @alignOf(boot.types.memory.UefiMemoryDescriptor) != 0 or map.DescriptorVersion != memory.DESCRIPTOR_VERSION)
    {
        return null;
    }
    const byte_size = @as(u64, map.EntryCount) * map.EntrySize;
    if (map.Entries >= physical_limit or byte_size > physical_limit - map.Entries) return null;
    const storage = state.getStorage();
    var entry_index: usize = 0;
    while (entry_index < map.EntryCount) : (entry_index += 1) {
        const descriptor_address = layout.PHYSMAP_BASE + map.Entries + @as(u64, entry_index) * map.EntrySize;
        const descriptor: *const boot.types.memory.UefiMemoryDescriptor = @ptrFromInt(descriptor_address);
        if ((descriptor.PhysicalStart & sizes.PAGE_MASK) != 0 or descriptor.NumberOfPages == 0 or
            descriptor.NumberOfPages > (std.math.maxInt(u64) - descriptor.PhysicalStart) / sizes.PAGE_SIZE)
        {
            return null;
        }
        const length = descriptor.NumberOfPages * sizes.PAGE_SIZE;
        const end = descriptor.PhysicalStart + length;
        for (storage[0..entry_index]) |previous| {
            if (descriptor.PhysicalStart < previous.BaseAddress + previous.Length and previous.BaseAddress < end) return null;
        }
        storage[entry_index] = .{
            .BaseAddress = descriptor.PhysicalStart,
            .Length = length,
            .RegionType = classify(descriptor.MemoryType),
        };
    }
    return storage[0..map.EntryCount];
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
