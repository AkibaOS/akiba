//! Paging Index Constants

pub const pml4_shift: u6 = 39;
pub const pdpt_shift: u6 = 30;
pub const pd_shift: u6 = 21;
pub const pt_shift: u6 = 12;

pub const index_mask: u64 = 0x1FF;

pub const pml4_index_mask: u64 = index_mask << pml4_shift;
pub const pdpt_index_mask: u64 = index_mask << pdpt_shift;
pub const pd_index_mask: u64 = index_mask << pd_shift;
pub const pt_index_mask: u64 = index_mask << pt_shift;

pub const address_mask: u64 = 0x000FFFFFFFFFF000;
pub const offset_mask: u64 = 0xFFF;

pub fn extract_pml4_index(virtual_address: u64) u9 {
    return @truncate((virtual_address >> pml4_shift) & index_mask);
}

pub fn extract_pdpt_index(virtual_address: u64) u9 {
    return @truncate((virtual_address >> pdpt_shift) & index_mask);
}

pub fn extract_pd_index(virtual_address: u64) u9 {
    return @truncate((virtual_address >> pd_shift) & index_mask);
}

pub fn extract_pt_index(virtual_address: u64) u9 {
    return @truncate((virtual_address >> pt_shift) & index_mask);
}

pub fn extract_offset(virtual_address: u64) u12 {
    return @truncate(virtual_address & offset_mask);
}
