//! UEFI Memory Map Conversion

const common = @import("common");

const boot = @import("shared").boot;
const constants = @import("mirai").boot.constants;
const pmm = @import("mirai").pmm;
const state = @import("mirai").boot.regions.state;

const limits = constants.regions.limits;
const sizes = common.constants.memory.sizes;

const MemoryRegion = pmm.types.region.MemoryRegion;
const RegionType = pmm.types.region.RegionType;

pub fn convert(map: boot.types.memory.MemoryMapInfo) []const MemoryRegion {
    const storage = state.getStorage();

    var region_count: usize = 0;
    var entry_index: u32 = 0;

    while (entry_index < map.EntryCount and region_count < limits.MAX_REGIONS) : (entry_index += 1) {
        const descriptor_address = map.Entries + @as(u64, entry_index) * map.EntrySize;
        const descriptor: *const boot.types.memory.UefiMemoryDescriptor = @ptrFromInt(descriptor_address);

        storage[region_count] = MemoryRegion{
            .BaseAddress = descriptor.PhysicalStart,
            .Length = descriptor.NumberOfPages * sizes.PAGE_SIZE,
            .RegionType = classify(descriptor.MemoryType),
        };
        region_count += 1;
    }

    return storage[0..region_count];
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
