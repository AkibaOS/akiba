//! Paging Index Constants

pub const PML4_SHIFT: u6 = 39;
pub const PDPT_SHIFT: u6 = 30;
pub const PD_SHIFT: u6 = 21;
pub const PT_SHIFT: u6 = 12;

pub const INDEX_MASK: u64 = 0x1FF;

pub const PML4_INDEX_MASK: u64 = INDEX_MASK << PML4_SHIFT;
pub const PDPT_INDEX_MASK: u64 = INDEX_MASK << PDPT_SHIFT;
pub const PD_INDEX_MASK: u64 = INDEX_MASK << PD_SHIFT;
pub const PT_INDEX_MASK: u64 = INDEX_MASK << PT_SHIFT;

pub const ADDRESS_MASK: u64 = 0x000FFFFFFFFFF000;
pub const OFFSET_MASK: u64 = 0xFFF;
