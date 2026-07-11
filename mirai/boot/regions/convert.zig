//! UEFI Memory Map Conversion

const root = @import("root");
const constants = @import("constants/constants.zig");
const state = @import("state.zig");
const boot_params = @import("../../kernel/boot.zig");

const MemoryRegion = root.pmm.types.MemoryRegion;

pub fn convert(map: boot_params.MemoryMapInfo) []const MemoryRegion {
    const storage = state.get_storage();

    var region_count: usize = 0;
    var entry_index: u32 = 0;

    while (entry_index < map.entry_count and region_count < constants.max_regions) : (entry_index += 1) {
        const descriptor_address = map.entries + @as(u64, entry_index) * map.entry_size;
        const descriptor: *const boot_params.UefiMemoryDescriptor = @ptrFromInt(descriptor_address);

        storage[region_count] = MemoryRegion{
            .base_address = descriptor.physical_start,
            .length = descriptor.number_of_pages * 4096,
            .region_type = classify(descriptor.memory_type),
        };
        region_count += 1;
    }

    return storage[0..region_count];
}

fn classify(memory_type: boot_params.UefiMemoryType) MemoryRegion.RegionType {
    return switch (memory_type) {
        .conventional => .available,
        .acpi_reclaim => .acpi_reclaimable,
        .acpi_nvs => .acpi_nvs,
        .unusable => .bad,
        else => .reserved,
    };
}
