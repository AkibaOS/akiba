//! Address Translation

const common = @import("common");

const layout = common.constants.memory.layout;
const sizes = common.constants.memory.sizes;

pub fn addressToPage(address: u64) u64 {
    return address >> sizes.PAGE_SHIFT;
}

pub fn pageToAddress(page_number: u64) u64 {
    return page_number << sizes.PAGE_SHIFT;
}

pub fn physToVirt(physical_address: u64) u64 {
    return physical_address + layout.PHYSMAP_BASE;
}

pub fn virtToPhys(virtual_address: u64) u64 {
    return virtual_address - layout.PHYSMAP_BASE;
}
