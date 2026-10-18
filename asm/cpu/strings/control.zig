//! CPU Control Register Instruction Strings

pub const READ_CR0 = "mov %%cr0, %[result]";
pub const WRITE_CR0 = "mov %[value], %%cr0";
pub const READ_CR2 = "mov %%cr2, %[result]";
pub const READ_CR3 = "mov %%cr3, %[result]";
pub const WRITE_CR3 = "mov %[value], %%cr3";
pub const READ_CR4 = "mov %%cr4, %[result]";
pub const WRITE_CR4 = "mov %[value], %%cr4";
pub const INVALIDATE_PAGE = "invlpg (%[address])";
