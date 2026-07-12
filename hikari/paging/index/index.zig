//! Hikari Page Table Index Extraction

const common = @import("common");

const indices = common.constants.paging.indices;

pub fn extractL4Index(address: u64) usize {
    return @truncate((address >> indices.PML4_SHIFT) & indices.INDEX_MASK);
}

pub fn extractL3Index(address: u64) usize {
    return @truncate((address >> indices.PDPT_SHIFT) & indices.INDEX_MASK);
}

pub fn extractL2Index(address: u64) usize {
    return @truncate((address >> indices.PD_SHIFT) & indices.INDEX_MASK);
}

pub fn extractL1Index(address: u64) usize {
    return @truncate((address >> indices.PT_SHIFT) & indices.INDEX_MASK);
}

pub fn extractPageOffset(address: u64) usize {
    return @truncate(address & indices.OFFSET_MASK);
}
