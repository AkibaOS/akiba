//! Kagami Table Constants

pub const pml4_entries: u64 = 512;
pub const pdpt_entries: u64 = 512;
pub const pd_entries: u64 = 512;
pub const pt_entries: u64 = 512;

pub const kernel_pml4_start: u64 = 256;
pub const kernel_pml4_end: u64 = 512;

pub const user_pml4_start: u64 = 0;
pub const user_pml4_end: u64 = 256;
