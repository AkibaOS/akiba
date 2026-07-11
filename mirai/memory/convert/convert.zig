//! Physical-Virtual Address Conversion

const common = @import("root").common;
const layout = common.constants.memory.layout;

pub fn phys_to_virt(phys: u64) u64 {
    return phys + layout.physmap_base;
}

pub fn virt_to_phys(virt: u64) u64 {
    return virt - layout.physmap_base;
}
