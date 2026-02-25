//! Physical Memory Manager Constants

pub const max_physical_memory: u64 = 512 * 1024 * 1024 * 1024;
pub const max_physical_pages: u64 = max_physical_memory / 4096;
pub const bitmap_size_bytes: u64 = max_physical_pages / 8;

pub const memory_region_available: u32 = 1;
pub const memory_region_reserved: u32 = 2;
pub const memory_region_acpi_reclaimable: u32 = 3;
pub const memory_region_acpi_nvs: u32 = 4;
pub const memory_region_bad: u32 = 5;
