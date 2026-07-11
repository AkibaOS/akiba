//! Memory Layout Constants

pub const kernel_base: u64 = 0xFFFFFFFF80000000;
pub const kernel_physical_base: u64 = 0x100000;

pub const physmap_base: u64 = 0xFFFF800000000000;
pub const physmap_max_size: u64 = 512 * 1024 * 1024 * 1024;

pub const kernel_stack_area_base: u64 = 0xFFFF880000000000;
pub const kernel_stack_area_size: u64 = 512 * 1024 * 1024 * 1024;

pub const kernel_heap: u64 = 0xFFFF900000000000;
pub const mmio_base: u64 = 0xFFFFF00000000000;

pub const user_space_start: u64 = 0x0000000000000000;
pub const user_space_end: u64 = 0x00007FFFFFFFFFFF;

pub const kernel_stack_size: u64 = 64 * 1024;
pub const kernel_stack_pages: u64 = kernel_stack_size / 4096;
