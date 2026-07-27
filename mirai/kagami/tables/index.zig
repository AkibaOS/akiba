//! Page Table Index Extraction

const common = @import("common");

const indices = common.constants.paging.indices;

pub fn extractPML4Index(virtual_address: u64) u9 {
    return @truncate((virtual_address >> indices.PML4_SHIFT) & indices.INDEX_MASK);
}

pub fn extractPDPTIndex(virtual_address: u64) u9 {
    return @truncate((virtual_address >> indices.PDPT_SHIFT) & indices.INDEX_MASK);
}

pub fn extractPDIndex(virtual_address: u64) u9 {
    return @truncate((virtual_address >> indices.PD_SHIFT) & indices.INDEX_MASK);
}

pub fn extractPTIndex(virtual_address: u64) u9 {
    return @truncate((virtual_address >> indices.PT_SHIFT) & indices.INDEX_MASK);
}

pub fn extractOffset(virtual_address: u64) u12 {
    return @truncate(virtual_address & indices.OFFSET_MASK);
}
