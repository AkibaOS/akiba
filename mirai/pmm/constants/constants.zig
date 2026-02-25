//! Physical Memory Manager Constants

pub const limits = @import("limits.zig");

pub const max_physical_memory = limits.max_physical_memory;
pub const max_physical_pages = limits.max_physical_pages;
pub const bitmap_size_bytes = limits.bitmap_size_bytes;

pub const memory_region_available = limits.memory_region_available;
pub const memory_region_reserved = limits.memory_region_reserved;
pub const memory_region_acpi_reclaimable = limits.memory_region_acpi_reclaimable;
pub const memory_region_acpi_nvs = limits.memory_region_acpi_nvs;
pub const memory_region_bad = limits.memory_region_bad;
