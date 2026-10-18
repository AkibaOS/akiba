//! Physical Memory Manager Limits

const common = @import("common");

const layout = common.constants.memory.layout;

pub const MAX_PHYSICAL_MEMORY: u64 = layout.PHYSMAP_MAX_SIZE;
pub const BITMAP_ALL_USED: u8 = 0xFF;

pub const KERNEL_RESERVED_PAGES: u64 = 0x200;

pub const MEMORY_REGION_AVAILABLE: u32 = 1;
pub const MEMORY_REGION_RESERVED: u32 = 2;
pub const MEMORY_REGION_ACPI_RECLAIMABLE: u32 = 3;
pub const MEMORY_REGION_ACPI_NVS: u32 = 4;
pub const MEMORY_REGION_BAD: u32 = 5;
