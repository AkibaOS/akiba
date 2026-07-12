//! Region Conversion State

const root = @import("root");
const constants = @import("../constants/regions/regions.zig");

const MemoryRegion = root.pmm.types.MemoryRegion;

var region_storage: [constants.max_regions]MemoryRegion = undefined;

pub fn get_storage() *[constants.max_regions]MemoryRegion {
    return &region_storage;
}
