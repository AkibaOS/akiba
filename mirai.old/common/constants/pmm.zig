//! Physical memory manager constants

pub const MEMORY_AVAILABLE: u32 = 1;

pub const FIRST_MB: u64 = 0x100000;
pub const KERNEL_BASE: u64 = 0x100000;
pub const KERNEL_MAP_END: u64 = 0x10000000; // 256MB

pub const MMIO_FRAMEBUFFER_BASE: u64 = 0x80000000;
pub const MMIO_FRAMEBUFFER_SIZE: u64 = 0x10000000;
pub const MMIO_PCI_BASE: u64 = 0xE0000000;
pub const MMIO_PCI_SIZE: u64 = 0x10000000;

pub const BITMAP_MARK_USED: u8 = 0xFF;
