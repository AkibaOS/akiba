//! Region Conversion State

const constants = @import("mirai").boot.constants;
const pmm = @import("mirai").pmm;

const limits = constants.regions.limits;

const MemoryRegion = pmm.types.region.MemoryRegion;

var region_storage: [limits.MAX_REGIONS]MemoryRegion = undefined;

pub fn getStorage() *[limits.MAX_REGIONS]MemoryRegion {
    return &region_storage;
}
