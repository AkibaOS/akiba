//! Physical-Virtual Address Conversion

const common = @import("common");

const layout = common.constants.memory.layout;

pub fn physToVirt(physical: u64) u64 {
    return physical + layout.PHYSMAP_BASE;
}

pub fn virtToPhys(virtual: u64) u64 {
    return virtual - layout.PHYSMAP_BASE;
}
