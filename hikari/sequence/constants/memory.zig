//! Hikari Boot Sequence Memory Constants

const common = @import("common");

const sizes = common.constants.memory.sizes;

pub const IDENTITY_MAP_SIZE: u64 = 4 * sizes.GIGABYTE;
pub const PHYSMAP_MAP_SIZE: u64 = 16 * sizes.GIGABYTE;

pub const MEMORY_MAP_EXTRA_DESCRIPTORS: usize = 2;
